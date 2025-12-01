#!/usr/bin/env bash
set -euo pipefail

# Test different colour temperature adjustments
for temp in "0.98:1.02" "0.96:1.04" "0.94:1.06"; do
  IFS=':' read -r gamma_r gamma_b <<< "$temp"
  echo "Testing gamma_r=$gamma_r gamma_b=$gamma_b"

  ffmpeg -ss 00:00:30 -i "sample.mkv" -t 30 \
    -vf "eq=saturation=0.85:gamma_r=$gamma_r:gamma_b=$gamma_b,drawtext=text='r=$gamma_r b=$gamma_b':x=10:y=10:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5" \
    -c:v libx264 -crf 22 -preset veryfast \
    "test-temp-r${gamma_r}-b${gamma_b}.mkv"
done

echo "Test clips created. Find the best colour balance."
