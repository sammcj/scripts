#!/bin/bash
set -euo pipefail

# Version 1.0.1 - 2021-10-25
#
# RAID optimisation script
#
# Tuned for:
# - 6 WD-RED Pro disks
# - RAID 10
# - CentOS 7 with Kernel 5.14+
# - 32GB+ of RAM

# Increase (re)sync speed
echo 99999999 >/sys/block/md0/md/sync_speed_max
sysctl -w dev.raid.speed_limit_min=9999999
sysctl -w dev.raid.speed_limit_max=9999999

# Set readahead on array
blockdev --setra 65536 /dev/md0
blockdev --setra 65536 /dev/md0p1

# Use more memory for caching
sysctl vm.dirty_background_ratio=20
sysctl vm.dirty_ratio=30

modprobe bfq
for d in /sys/block/sd?; do
  if test "$(cat "$d/queue/rotational")" = "1"; then
    for r in /sys/block/sd?; do
      # Use new BFQ scheduler
      echo bfq >"$r/queue/scheduler"

      # Disable NCQ
      echo 1 >"$r/device/queue_depth"

      # Read ahead cache
      echo 512 >"$r/queue/read_ahead_kb"
    done
  fi
done
