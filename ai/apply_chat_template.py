#!/usr/bin/env python3
"""Recursively update Qwen 3.5/3.6 chat templates to a canonical jinja file.

Handles two artefact types found under a models tree:

  * GGUF files  - rewritten via gguf_new_metadata.py (a full copy with the
    tokenizer.chat_template metadata replaced, then atomically swapped in).
  * chat_template.jinja files - plain-text templates shipped alongside MLX or
    unquantised models; overwritten in place.

A file is only touched when its current template differs from the target
(compared after stripping trailing whitespace). Dry-run by default; pass
--apply to make changes.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from gguf import GGUFReader

# Default locations (override on the CLI if needed).
DEFAULT_MODELS_DIR = Path("/Users/samm/.lmstudio/models")
DEFAULT_TEMPLATE = Path(
    "/Users/samm/git/Qwen-Fixed-Chat-Templates/chat_template.jinja"
)
GGUF_NEW_METADATA = Path(
    "/Users/samm/git/llama.cpp/gguf-py/gguf/scripts/gguf_new_metadata.py"
)

# Matches Qwen3.5 / Qwen3.6 / Qwen_Qwen3.6 etc. but NOT Qwen3-Embedding.
QWEN_VERSION_RE = re.compile(r"[Qq]wen_?3\.?[56]")
# A non-first shard of a split GGUF (the template lives only in shard 00001).
NON_FIRST_SHARD_RE = re.compile(r"-(\d{5})-of-\d{5}\.gguf$")


def norm(text: str) -> str:
    """Normalise for comparison: ignore trailing whitespace differences."""
    return text.rstrip()


def is_target_qwen(path: Path) -> bool:
    return bool(QWEN_VERSION_RE.search(str(path)))


def gguf_candidates(models_dir: Path) -> list[Path]:
    out = []
    for p in models_dir.rglob("*.gguf"):
        name = p.name
        if name.startswith("mmproj") or "mmproj" in name:
            continue
        if "Embedding" in str(p):
            continue
        m = NON_FIRST_SHARD_RE.search(name)
        if m and m.group(1) != "00001":
            continue
        if not is_target_qwen(p):
            continue
        out.append(p)
    return sorted(out)


def jinja_candidates(models_dir: Path) -> list[Path]:
    return sorted(
        p
        for p in models_dir.rglob("chat_template.jinja")
        if is_target_qwen(p)
    )


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha_log_path(model_path: Path) -> Path:
    return model_path.with_name(model_path.name + ".chat-template-change-sha256.txt")


def has_before_entry(model_path: Path) -> bool:
    log = sha_log_path(model_path)
    return log.exists() and bool(log.read_text(encoding="utf-8").strip())


def record_before(model_path: Path) -> bool:
    """Log the current file's SHA256 as the 'before' state, once.

    Idempotent and non-destructive: does nothing if a 'before' entry already
    exists. Safe to call during a dry-run. Returns True if it wrote the entry.
    """
    if has_before_entry(model_path):
        return False
    sha = sha256_file(model_path)
    with open(sha_log_path(model_path), "w", encoding="utf-8") as f:
        f.write(f"Before applying chat template\nsha256:{sha}\n")
    return True


def append_after(model_path: Path, after_sha: str) -> None:
    """Append a dated 'after' block, preserving the original 'before'."""
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    with open(sha_log_path(model_path), "a", encoding="utf-8") as f:
        f.write(f"\nAfter applying chat template {stamp}\nsha256:{after_sha}\n")


def read_gguf_template(path: Path) -> str | None:
    reader = GGUFReader(path)
    field = reader.get_field("tokenizer.chat_template")
    if field is None:
        return None
    return field.contents()


def update_gguf(path: Path, target: str, template_path: Path, apply: bool) -> str:
    current = read_gguf_template(path)
    if current is None:
        return "skip (no chat_template field)"
    if norm(current) == norm(target):
        return "ok (already up to date)"
    if not apply:
        logged = record_before(path)
        return f"WOULD UPDATE (dry-run{'; before SHA logged' if logged else '; before SHA already logged'})"

    record_before(path)  # capture pre-rewrite state unless a dry-run already did
    tmp = path.with_suffix(path.suffix + ".tmpnew")
    start = time.monotonic()
    try:
        subprocess.run(
            [
                sys.executable,
                str(GGUF_NEW_METADATA),
                str(path),
                str(tmp),
                "--chat-template-file",
                str(template_path),
                "--force",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        os.replace(tmp, path)
    except subprocess.CalledProcessError as exc:
        tmp.unlink(missing_ok=True)
        return f"ERROR: {exc.stderr.strip().splitlines()[-1] if exc.stderr else exc}"
    finally:
        tmp.unlink(missing_ok=True)
    elapsed = time.monotonic() - start
    after_sha = sha256_file(path)
    append_after(path, after_sha)
    size_gb = path.stat().st_size / 1e9
    return f"UPDATED in {elapsed:.1f}s ({size_gb:.1f} GB)"


def update_jinja(path: Path, target: str, apply: bool) -> str:
    current = path.read_text(encoding="utf-8")
    if norm(current) == norm(target):
        return "ok (already up to date)"
    if not apply:
        return "WOULD UPDATE (dry-run)"
    path.write_text(target, encoding="utf-8")
    return "UPDATED"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--models-dir", type=Path, default=DEFAULT_MODELS_DIR)
    ap.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    ap.add_argument("--apply", action="store_true", help="make changes (default: dry-run)")
    ap.add_argument("--only", choices=["gguf", "jinja"], help="limit to one artefact type")
    ap.add_argument(
        "--match",
        help="only process files whose path contains this substring (e.g. '4B')",
    )
    args = ap.parse_args()

    target = args.template.read_text(encoding="utf-8")
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"[{mode}] target template: {args.template} ({len(target)} chars)\n")

    work: list[tuple[str, Path]] = []
    if args.only in (None, "gguf"):
        work += [("gguf", p) for p in gguf_candidates(args.models_dir)]
    if args.only in (None, "jinja"):
        work += [("jinja", p) for p in jinja_candidates(args.models_dir)]

    if args.match:
        work = [(k, p) for k, p in work if args.match in str(p)]

    if not work:
        print("No matching files found.")
        return 0

    changed = 0
    for kind, path in work:
        rel = path.relative_to(args.models_dir)
        if kind == "gguf":
            result = update_gguf(path, target, args.template, args.apply)
        else:
            result = update_jinja(path, target, args.apply)
        if "UPDATE" in result or "UPDATED" in result:
            changed += 1
        print(f"  [{kind:5}] {rel}\n          -> {result}")

    print(f"\n{changed} file(s) {'changed' if args.apply else 'would change'}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
