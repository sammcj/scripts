#!/usr/bin/env python3
"""Detect locally downloaded models that have been replaced or updated upstream on HuggingFace.

Scans a directory tree of GGUF and MLX models, maps each to its HuggingFace repo, and compares
the local weight files against the current upstream revision (the `main` branch tree).

Defaults to ~/.lmstudio/models on macOS or /mnt/llm/models on Linux; override with --path
(repeatable). Works for models downloaded by LM Studio and for models placed in the same tree
by other tools.

Local file identity is resolved as cheaply as possible:
  1. HuggingFace download metadata (.cache/huggingface/download/<file>.metadata) records the LFS
     sha256 - used directly, no hashing.
  2. A local state cache keyed by (path, size, mtime) - reused on subsequent runs.
  3. Otherwise sha256 is computed, but ONLY when the local size matches upstream (a size mismatch
     already proves the file differs) and only for one representative file per model - a sharded
     model isn't hashed shard by shard. Use --hash to verify every shard.

Upstream repo trees are cached on disk (default 12h) to limit API calls. Set HF_TOKEN to raise
rate limits. State lives in ~/.cache/model-staleness/state.json.

If a weight file has a `<file>.chat-template-change-sha256.txt` sidecar (written by
apply_chat_template.py), the recorded pre-edit sha256 is compared to upstream instead of the
modified on-disk file. Such models report as `modified` (local edit, original matched upstream)
rather than a false `stale`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

WEIGHT_EXTS = (".gguf", ".safetensors")
IGNORE_DIRS = {".cache", "assets", "tmp", ".git", "__pycache__", ".ipynb_checkpoints"}
# Sidecar written by apply_chat_template.py: records the pre-edit sha256 of a weight file.
CHAT_TEMPLATE_SIDECAR = ".chat-template-change-sha256.txt"
SHARD_RE = re.compile(r"-\d{5}-of-\d{5}\.(gguf|safetensors)$")
HEX64_RE = re.compile(r"^[0-9a-f]{64}$")
HASH_CHUNK = 8 * 1024 * 1024
HF_API = "https://huggingface.co/api/models"

STATE_DIR = os.path.expanduser("~/.cache/model-staleness")
STATE_FILE = os.path.join(STATE_DIR, "state.json")

# Status precedence (worst first) used to roll file statuses up to a model verdict.
STATUS_RANK = {
    "stale": 0,
    "error": 1,
    "not-found": 2,
    "not-on-hf": 3,
    "unknown": 4,
    "not-upstream": 5,
    "modified": 6,
    "current": 7,
}


# --------------------------------------------------------------------------- state


def load_state() -> dict:
    try:
        with open(STATE_FILE, encoding="utf-8") as fh:
            data = json.load(fh)
    except (FileNotFoundError, ValueError):
        data = {}
    data.setdefault("version", 1)
    data.setdefault("local", {})  # abspath -> {size, mtime_ns, sha256}
    data.setdefault("hf", {})     # repo_id -> {fetched_at, files: {name: {size, lfs, blob}}}
    return data


def save_state(state: dict) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2, sort_keys=True)
    os.replace(tmp, STATE_FILE)


# --------------------------------------------------------------------- discovery


def default_roots() -> list[str]:
    if platform.system() == "Darwin":
        return [os.path.expanduser("~/.lmstudio/models")]
    return ["/mnt/llm/models"]


def is_weight(name: str) -> bool:
    return name.endswith(WEIGHT_EXTS)


def discover_models(root: str) -> dict[str, list[str]]:
    """Return {model_dir: [weight_filenames]} for every dir holding at least one weight file."""
    found: dict[str, list[str]] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS and not d.startswith(".")]
        weights = sorted(f for f in filenames if is_weight(f))
        if weights:
            found[dirpath] = weights
    return found


def resolve_repo(model_dir: str, root: str) -> str | None:
    """Map a model directory to a HuggingFace repo id (org/repo), or None if it can't be."""
    rel = os.path.relpath(model_dir, root)
    parts = [p for p in rel.split(os.sep) if p and p != "."]
    if len(parts) >= 2:
        return f"{parts[0]}/{parts[1]}"
    # Flattened/custom directory: try the model config for a source repo hint.
    cfg = os.path.join(model_dir, "config.json")
    try:
        with open(cfg, encoding="utf-8") as fh:
            name = json.load(fh).get("_name_or_path", "")
        if name.count("/") == 1 and not name.startswith((".", "/")):
            return name
    except (FileNotFoundError, ValueError):
        pass
    return None


# ------------------------------------------------------------------ local hashes


def read_hf_metadata_sha(model_dir: str, filename: str) -> str | None:
    """Return the LFS sha256 HuggingFace recorded at download time, if available."""
    meta = os.path.join(model_dir, ".cache", "huggingface", "download", filename + ".metadata")
    try:
        with open(meta, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except FileNotFoundError:
        return None
    etag = lines[1].strip() if len(lines) >= 2 else ""
    return etag if HEX64_RE.match(etag) else None


def read_before_sha(weight_path: str) -> str | None:
    """Return the pre-edit sha256 recorded by apply_chat_template.py, if a sidecar exists.

    Sidecar format is a 'Before applying chat template' header followed by a 'sha256:<hex>'
    line, then zero or more dated 'After applying...' blocks. Only the 'before' value matters
    here: it is the content we originally downloaded, which is what should be compared upstream.
    """
    try:
        with open(weight_path + CHAT_TEMPLATE_SIDECAR, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
    except FileNotFoundError:
        return None
    for i, line in enumerate(lines):
        if line.strip().lower() != "before applying chat template":
            continue
        for nxt in lines[i + 1:]:
            s = nxt.strip().lower()
            if s.startswith("after applying"):
                break
            if s.startswith("sha256:"):
                val = s.split(":", 1)[1].strip()
                return val if HEX64_RE.match(val) else None
    return None


def local_sha256(path: str, st: os.stat_result, state: dict, log, label: str = "") -> str:
    """sha256 of a local file, cached by (path, size, mtime_ns) across runs."""
    cache = state["local"]
    rec = cache.get(path)
    if rec and rec.get("size") == st.st_size and rec.get("mtime_ns") == st.st_mtime_ns:
        return rec["sha256"]
    where = f"{label}: " if label else ""
    log(f"  hashing {where}{os.path.basename(path)} ({st.st_size / 1e9:.1f} GB)...")
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(HASH_CHUNK), b""):
            h.update(chunk)
    digest = h.hexdigest()
    cache[path] = {"size": st.st_size, "mtime_ns": st.st_mtime_ns, "sha256": digest}
    return digest


# -------------------------------------------------------------------- hf upstream


def fetch_tree(repo: str, token: str | None) -> dict[str, dict]:
    """Fetch the upstream file tree -> {basename: {size, lfs, blob}}. Raises on HTTP/network error."""
    files: dict[str, dict] = {}
    url = f"{HF_API}/{urllib.parse.quote(repo)}/tree/main?recursive=true"
    headers = {"User-Agent": "model-staleness/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    while url:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            for entry in json.load(resp):
                if entry.get("type") != "file":
                    continue
                lfs = entry.get("lfs") or {}
                files[os.path.basename(entry["path"])] = {
                    "size": lfs.get("size", entry.get("size")),
                    "lfs": lfs.get("oid"),
                    "blob": entry.get("oid"),
                }
            url = _next_link(resp.headers.get("Link"))
    return files


def _next_link(link_header: str | None) -> str | None:
    if not link_header:
        return None
    for part in link_header.split(","):
        if 'rel="next"' in part:
            return part[part.find("<") + 1 : part.find(">")]
    return None


def fetch_gated(repo: str, token: str | None) -> str | None:
    """Return the repo's gating mode ('auto'/'manual') or None if ungated/unknown.

    Gating is read from the model metadata endpoint: gated repos still serve
    metadata and the file tree publicly (gating only blocks file *downloads*),
    so a 401/403 means not-found/private, never gated.
    """
    url = f"{HF_API}/{urllib.parse.quote(repo)}"
    headers = {"User-Agent": "model-staleness/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as resp:
            gated = json.load(resp).get("gated")
    except (urllib.error.URLError, OSError, ValueError):
        return None  # best-effort probe: never let a gating lookup break the scan
    return gated if gated in ("auto", "manual") else None


def upstream_tree(repo: str, state: dict, token: str | None, ttl: float, refresh: bool):
    """Return (files, status, gated). status is 'ok', 'not-on-hf', 'not-found' or 'error'.

    gated is 'auto'/'manual' when the repo requires licence acceptance, else None.
    """
    cached = state["hf"].get(repo)
    if cached and not refresh and (time.time() - cached.get("fetched_at", 0)) < ttl:
        return cached["files"], "ok", cached.get("gated")
    try:
        files = fetch_tree(repo, token)
    except urllib.error.HTTPError as err:
        if err.code in (401, 403):
            return None, "not-found", None  # private/renamed/nonexistent (HF hides which)
        if err.code == 404:
            return None, "not-on-hf", None
        if cached:
            return cached["files"], "ok", cached.get("gated")
        return None, "error", None
    except (urllib.error.URLError, TimeoutError, ValueError):
        if cached:
            return cached["files"], "ok", cached.get("gated")
        return None, "error", None
    gated = fetch_gated(repo, token)
    state["hf"][repo] = {"fetched_at": time.time(), "files": files, "gated": gated}
    return files, "ok", gated


# ---------------------------------------------------------------------- compare


def compare_file(model_dir, filename, upstream, state, allow_hash, log, label="") -> dict:
    """Compare one local weight file to its upstream entry. Returns a result dict.

    Free checks (size, HF metadata etag, chat-template sidecar) always run. A sha256 is only
    computed when nothing cheaper resolves it and allow_hash is set - the caller grants that to
    one representative file per model so a sharded model isn't hashed shard by shard.
    """
    path = os.path.join(model_dir, filename)
    st = os.stat(path)
    up = upstream.get(filename)
    res = {"name": filename, "local_size": st.st_size, "upstream_size": None, "local_sha": None,
           "upstream_sha": None, "local_modified": False, "sha_source": None, "status": None}
    if up is None:
        res["status"] = "not-upstream"
        return res
    res["upstream_size"] = up["size"]
    res["upstream_sha"] = up["lfs"]
    # A locally chat-template-edited file diverges from upstream in size and sha, but the sidecar
    # records the original pre-edit sha. Compare that to upstream: matches -> local edit (not stale),
    # differs -> upstream genuinely replaced. Needs no hashing and bypasses the size fast-path.
    before = read_before_sha(path)
    if before is not None:
        res["local_sha"], res["local_modified"], res["sha_source"] = before, True, "sidecar"
        res["status"] = "current" if up["lfs"] is None else ("modified" if before == up["lfs"] else "stale")
        return res
    if up["size"] is not None and up["size"] != st.st_size:
        res["status"], res["sha_source"] = "stale", "size"  # size differs - replaced, no hashing
        return res
    if up["lfs"] is None:
        res["status"], res["sha_source"] = "current", "size"  # non-LFS file, matching size
        return res
    local = read_hf_metadata_sha(model_dir, filename)
    if local is not None:
        res["local_sha"], res["sha_source"] = local, "metadata"
        res["status"] = "current" if local == up["lfs"] else "stale"
        return res
    if not allow_hash:  # size matched upstream but hash budget spent on another shard
        res["status"], res["sha_source"] = "current", "size-only"
        return res
    local = local_sha256(path, st, state, log, label)
    res["local_sha"], res["sha_source"] = local, "computed"
    res["status"] = "current" if local == up["lfs"] else "stale"
    return res


def roll_up(file_results: list[dict]) -> str:
    return min((r["status"] for r in file_results), key=lambda s: STATUS_RANK.get(s, 99))


# ------------------------------------------------------------------------ output


COLORS = {"stale": "31", "current": "32", "not-on-hf": "33", "not-found": "33",
          "error": "31", "unknown": "33", "not-upstream": "36", "modified": "35",
          "unknown-repo-map": "33", "gated": "33"}


def colour(text: str, status: str, enabled: bool) -> str:
    code = COLORS.get(status)
    return f"\033[{code}m{text}\033[0m" if enabled and code else text


def print_report(results: list[dict], use_colour: bool, only_stale: bool) -> None:
    counts: dict[str, int] = {}
    gated_count = 0
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
        if r.get("gated"):
            gated_count += 1
        if only_stale and r["status"] != "stale":
            continue
        icon = {"stale": "STALE   ", "current": "current ", "not-on-hf": "not-hf  ",
                "not-found": "not-fnd ", "error": "error   ", "unknown": "unknown ",
                "not-upstream": "no-match", "modified": "modified",
                "unknown-repo-map": "no-repo "}.get(r["status"], "?")
        line = f"  {colour(icon, r['status'], use_colour)}  {r['label']}"
        if r["status"] == "unknown-repo-map":
            line += "  (could not map to a HF repo)"
        elif r["status"] == "not-found":
            line += f"  [{r['repo']}]  (no such repo, private, or renamed)"
        elif r["repo"]:
            line += f"  [{r['repo']}]"
        if r.get("gated"):
            line += colour(f"  (gated: {r['gated']} - needs licence acceptance)", "gated", use_colour)
        if r["status"] == "modified":
            line += "  (local chat-template edit; original matches upstream)"
        print(line)
        for fr in r.get("files", []):
            if fr["status"] == "stale":
                detail = _stale_detail(fr)
                print(f"      - {fr['name']}: {detail}")
    summary = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    if gated_count:
        summary += f", gated={gated_count}"
    print("\nSummary: " + summary)


def _stale_detail(fr: dict) -> str:
    if fr.get("local_modified") and fr["local_sha"] and fr["upstream_sha"]:
        return f"pre-edit sha {fr['local_sha'][:12]} -> upstream {fr['upstream_sha'][:12]}"
    if fr["upstream_size"] is not None and fr["local_size"] != fr["upstream_size"]:
        return f"size {fr['local_size']} -> upstream {fr['upstream_size']}"
    if fr["local_sha"] and fr["upstream_sha"]:
        return f"sha {fr['local_sha'][:12]} -> upstream {fr['upstream_sha'][:12]}"
    return "differs from upstream"


# -------------------------------------------------------------------------- main


def scan_model(model_dir, weights, root, state, token, ttl, refresh, do_hash, log) -> dict:
    repo = resolve_repo(model_dir, root)
    label = os.path.relpath(model_dir, root)
    if repo is None:
        return {"label": label, "repo": None, "status": "unknown-repo-map", "files": [], "gated": None}
    upstream, tree_status, gated = upstream_tree(repo, state, token, ttl, refresh)
    if tree_status != "ok":
        return {"label": label, "repo": repo, "status": tree_status, "files": [], "gated": None}
    files, hashed = [], False
    for f in weights:
        # Grant the compute budget to the first file that needs it, unless --hash verifies all.
        res = compare_file(model_dir, f, upstream, state, do_hash or not hashed, log, repo)
        if res["sha_source"] == "computed":
            hashed = True
        files.append(res)
    return {"label": label, "repo": repo, "status": roll_up(files), "files": files, "gated": gated}


def parse_args(argv) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--path", action="append", metavar="DIR",
                   help="model root to scan (repeatable; defaults by OS)")
    p.add_argument("--ttl", type=float, default=12.0, help="upstream cache lifetime in hours (default 12)")
    p.add_argument("--refresh", action="store_true", help="ignore cached upstream trees and refetch")
    p.add_argument("--hash", action="store_true", dest="do_hash",
                   help="hash every shard, not just one representative file per model (exhaustive)")
    p.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    p.add_argument("--only-stale", action="store_true", help="only report models that are out of date")
    p.add_argument("--no-color", action="store_true", help="disable coloured output")
    p.add_argument("--quiet", action="store_true", help="suppress progress messages")
    p.add_argument("--exit-code", action="store_true", help="exit 1 if any model is stale")
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv or sys.argv[1:])
    roots = [os.path.expanduser(p) for p in (args.path or default_roots())]
    token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
    log = (lambda *_: None) if args.quiet else (lambda *a: print(*a, file=sys.stderr))
    state = load_state()

    results: list[dict] = []
    try:
        for root in roots:
            if not os.path.isdir(root):
                log(f"skip: {root} (not a directory)")
                continue
            log(f"scanning {root} ...")
            for model_dir, weights in sorted(discover_models(root).items()):
                results.append(scan_model(model_dir, weights, root, state,
                                          token, args.ttl * 3600, args.refresh, args.do_hash, log))
                save_state(state)  # persist incrementally so long first-run hashing survives interruption
    except KeyboardInterrupt:
        save_state(state)
        log("\ninterrupted - computed hashes saved; rerun to resume")
        return 130

    save_state(state)

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        use_colour = not args.no_color and sys.stdout.isatty()
        print_report(results, use_colour, args.only_stale)

    if args.exit_code and any(r["status"] == "stale" for r in results):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
