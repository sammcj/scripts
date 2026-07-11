#!/usr/bin/env bash
set -euo pipefail

# Back up Creality K2 Pro settings to a local timestamped snapshot.
# Grabs Klipper/Moonraker config + Creality userdata (CFS slot assignments,
# calibration, version); skips logs and sliced gcodes. Unchanged files are
# hardlinked against the previous snapshot, so repeat runs are cheap on disk.
# Safe to run any time.

HOST="root@192.168.69.100"
DEST_BASE="${HOME}/printer-backups"
KEEP=0        # 0 = keep all snapshots; N = keep newest N and prune older
DRY_RUN=0

die() { echo "Error: ${1}" >&2; exit 1; }
log() { echo "[$(date +'%H:%M:%S')] ${1}" >&2; }

usage() {
  cat <<'EOF'
Usage: backup-k2pro.sh [-H user@host] [-d dir] [-k N] [-n]
  -H  SSH target         (default root@192.168.69.100)
  -d  backup base dir    (default ~/printer-backups)
  -k  keep newest N snapshots, prune older (default 0 = keep all)
  -n  dry run (show what rsync would transfer, write nothing)
EOF
}

while getopts ":H:d:k:nh" opt; do
  case "${opt}" in
    H) HOST="${OPTARG}" ;;
    d) DEST_BASE="${OPTARG}" ;;
    k) KEEP="${OPTARG}" ;;
    n) DRY_RUN=1 ;;
    h) usage; exit 0 ;;
    :) die "Option -${OPTARG} requires an argument" ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ "${KEEP}" =~ ^[0-9]+$ ]] || die "-k must be a non-negative integer"
command -v rsync >/dev/null 2>&1 || die "rsync is required but not installed"
command -v ssh   >/dev/null 2>&1 || die "ssh is required but not installed"

# Fail fast if the printer is not reachable.
ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${HOST}" true 2>/dev/null \
  || die "Cannot reach ${HOST} over SSH (printer off, or not on this network?)"

mkdir -p "${DEST_BASE}"
DEST_BASE="$(cd "${DEST_BASE}" && pwd)"   # absolutise for --link-dest

# Newest existing snapshot, found before the new one is created (for hardlinking).
prev="$(find "${DEST_BASE}" -maxdepth 1 -type d -name 'k2pro-*' 2>/dev/null | sort | tail -1 || true)"

stamp="$(date +%Y%m%d-%H%M%S)"
dest="${DEST_BASE}/k2pro-${stamp}"
mkdir -p "${dest}"

# backup_tree REMOTE_PATH LOCAL_SUBDIR [EXCLUDE...]
backup_tree() {
  local remote="${1}" sub="${2}"; shift 2
  local -a args=(-az)
  if (( DRY_RUN == 1 )); then args+=(--dry-run -v); fi
  local ex
  for ex in "${@}"; do args+=(--exclude="${ex}"); done
  if [[ -n "${prev}" && -d "${prev}/${sub}" ]]; then args+=(--link-dest="${prev}/${sub}"); fi
  args+=("${HOST}:${remote}" "${dest}/${sub}/")
  log "Backing up ${remote}"
  rsync "${args[@]}"
}

backup_tree "/mnt/UDISK/printer_data/"      "printer_data"      "logs/" "gcodes/"
backup_tree "/mnt/UDISK/creality/userdata/" "creality-userdata" "log/"

# Prune old snapshots (newest N kept, including the one just made).
if (( KEEP > 0 )); then
  mapfile -t snaps < <(find "${DEST_BASE}" -maxdepth 1 -type d -name 'k2pro-*' | sort)
  if (( ${#snaps[@]} > KEEP )); then
    for (( i = 0; i < ${#snaps[@]} - KEEP; i++ )); do
      if (( DRY_RUN == 1 )); then
        log "[dry-run] would prune ${snaps[i]}"
      else
        log "Pruning $(basename "${snaps[i]}")"
        rm -rf "${snaps[i]}"
      fi
    done
  fi
fi

if (( DRY_RUN == 1 )); then
  rmdir "${dest}" 2>/dev/null || true
  log "Dry run complete (nothing written)."
else
  ln -sfn "${dest}" "${DEST_BASE}/latest"
  log "Done: ${dest}"
  du -sh "${dest}" 2>/dev/null | awk '{print "[size] " $1}' >&2 || true
fi
