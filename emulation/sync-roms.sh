#!/usr/bin/env bash
set -euo pipefail

# Copy games from a ROCKNIX / EmulationStation SD card (lowercase es-de folder
# names) to a spruceOS SD card (all-caps short codes), remapping folder names.
#
# No-clobber: files already on the destination are skipped by name, no re-read
# (efficient on slow SD cards). Safe to re-run and re-runnable on a freshly
# formatted spruce card with the same layout.
#
# Usage:
#   ./sync-roms.sh                 # copy
#   DRY_RUN=true ./sync-roms.sh    # show what would copy, touch nothing
#   SRC=/path DST=/path ./sync-roms.sh   # override card paths
#
# Env overrides:
#   SRC       source card roms dir   (default: /Volumes/ROMS 1/roms)
#   DST       dest card Roms dir      (default: /Volumes/ROMS/Roms)
#   DRY_RUN   true|false              (default: false)
#   COPY_BIOS true|false              (default: false) copy roms/bios -> ../BIOS

SRC="${SRC:-/Volumes/ROMS 1/roms}"
DST="${DST:-/Volumes/ROMS/Roms}"
DRY_RUN="${DRY_RUN:-false}"
COPY_BIOS="${COPY_BIOS:-false}"

die() { echo "Error: ${1}" >&2; exit 1; }
log() { echo "[$(date +'%H:%M:%S')] ${1}"; }

# --- source folder -> destination folder ------------------------------------
# Edit this table if a future card names systems differently. Many source
# folders may map to the same destination (e.g. genesis + megadrive -> MD);
# no-clobber keeps that safe. Only mappings whose destination is a real spruce
# folder are listed; anything else is reported as unmapped at the end.
declare -A MAP=(
  [amiga]=AMIGA           [amstradcpc]=CPC        [arcade]=ARCADE
  [arduboy]=ARDUBOY       [atari2600]=ATARI       [atari5200]=FIFTYTWOHUNDRED
  [atari7800]=SEVENTYEIGHTHUNDRED                  [atari800]=EIGHTHUNDRED
  [atarilynx]=LYNX        [atarist]=ATARIST       [c64]=COMMODORE
  [channelf]=FAIRCHILD    [chip-8]=CHAI           [coleco]=COLECO
  [cps1]=CPS1             [cps2]=CPS2             [cps3]=CPS3
  [dreamcast]=DC          [doom]=DOOM             [easyrpg]=EASYRPG
  [famicom]=FC            [fbneo]=FBNEO           [fds]=FDS
  [gameandwatch]=GW       [gamegear]=GG           [gb]=GB
  [gba]=GBA               [gbc]=GBC               [genesis]=MD
  [intellivision]=INTELLIVISION                   [mame]=MAME2003PLUS
  [mame2003]=MAME2003PLUS [mastersystem]=MS       [megacd]=SEGACD
  [megadrive]=MD          [megaduck]=MEGADUCK     [msx]=MSX
  [n64]=N64               [naomi]=NAOMI           [nds]=NDS
  [neocd]=NEOCD           [neogeo]=NEOGEO         [nes]=FC
  [ngp]=NGP               [ngpc]=NGPC             [odyssey]=ODYSSEY
  [openbor]=OPENBOR       [pc]=DOS                [pc98]=PC98
  [pcengine]=PCE          [pcenginecd]=PCECD      [pico-8]=PICO8
  [pokemini]=POKE         [psp]=PSP               [psx]=PS
  [satellaview]=SATELLAVIEW                       [saturn]=SATURN
  [segacd]=SEGACD         [sega32x]=THIRTYTWOX    [sg-1000]=SEGASGONE
  [sfc]=SFC               [sgb]=SGB               [snes]=SFC
  [sufami]=SUFAMI         [supergrafx]=SGFX       [supervision]=SUPERVISION
  [tg16]=PCE              [tg16cd]=PCECD          [tic-80]=TIC
  [turbografx]=PCE        [turbografxcd]=PCECD    [vectrex]=VECTREX
  [vic20]=VIC20           [videopac]=VIDEOPAC     [virtualboy]=VB
  [wonderswan]=WS         [wonderswancolor]=WSC   [x68000]=X68000
  [zxspectrum]=ZXS
  # Per your instruction. 3ds is empty on the source and spruce has no 3DS
  # emulator, so nothing actually moves; the mapping is here if you want it.
  [3ds]=NDS
)

# Source folders that are not games (BIOS handled separately, junk ignored).
declare -A IGNORE=(
  [bios]=1 [bezels]=1 [themes]=1 [saves]=1 [savestates]=1 [screenshots]=1
  [wifi]=1 [storageupdate]=1 [ROCKNIX]=1 [music]=1 [moonlight]=1 [mplayer]=1
)

[[ -d "${SRC}" ]] || die "Source not found: ${SRC}"
[[ -d "${DST}" ]] || die "Destination not found: ${DST}"

# rsync 3.x flags. --ignore-existing = pure no-clobber (skip by name, no
# re-read). No perms/owner/group: exFAT/FAT can't store them. modify-window
# absorbs FAT's 2s timestamp granularity.
RSYNC_FLAGS=(
  --recursive --times --ignore-existing
  --no-perms --no-owner --no-group --modify-window=2
  --human-readable --info=progress2
  --exclude='.DS_Store' --exclude='._*'
  --exclude='.Spotlight-V100' --exclude='.Trashes' --exclude='.fseventsd'
)
[[ "${DRY_RUN}" == "true" ]] && RSYNC_FLAGS+=(--dry-run)

copy_dir() {
  local src_dir="${1}" dst_dir="${2}" label="${3}"
  # Skip empty / missing source, don't create pointless dest folders.
  [[ -d "${src_dir}" ]] || return 0
  if [[ -z "$(find "${src_dir}" -type f ! -name '.*' -print -quit 2>/dev/null)" ]]; then
    return 0
  fi
  log "${label}"
  mkdir -p "${dst_dir}"
  rsync "${RSYNC_FLAGS[@]}" "${src_dir}/" "${dst_dir}/"
}

main() {
  [[ "${DRY_RUN}" == "true" ]] && log "DRY RUN - no files will be written"
  log "Source: ${SRC}"
  log "Dest:   ${DST}"

  local src dst
  for src in $(printf '%s\n' "${!MAP[@]}" | sort); do
    dst="${MAP[${src}]}"
    copy_dir "${SRC}/${src}" "${DST}/${dst}" "${src} -> ${dst}"
  done

  if [[ "${COPY_BIOS}" == "true" ]]; then
    copy_dir "${SRC}/bios" "${DST}/../BIOS" "bios -> ../BIOS"
  fi

  # Report non-empty source folders that were neither mapped nor ignored.
  local d name reported=0
  for d in "${SRC}"/*/; do
    name="$(basename "${d}")"
    [[ -v 'MAP[${name}]' || -v 'IGNORE[${name}]' ]] && continue
    [[ -z "$(find "${d}" -type f ! -name '.*' -print -quit 2>/dev/null)" ]] && continue
    if (( reported == 0 )); then
      echo
      log "Unmapped source folders with games (no spruce equivalent, skipped):"
      reported=1
    fi
    echo "  - ${name}"
  done

  echo
  log "Done."
}

main "${@}"
