#!/usr/bin/env bash
set -euo pipefail

rm -f sample.mkv
ffmpeg -i sample.mkv -vf "split=2[a][b];[b]histogram,format=yuva444p[hh];[a][hh]overlay" -t 10 preview.mkv

# Re-encode sample with saturation configuration, matching original quality
saturation=0.85
rm -f "sample-fixed.mkv"
ffmpeg -i "sample.mkv" \
  -vf "eq=saturation=$saturation" \
  -c:v libx264 -crf 18 -preset slow \
  -c:a copy -c:s copy \
  -map 0 \
  -loglevel warning \
  "sample-fixed.mkv"

# Extract a frame from both files for comparison
rm -f original-frame.png fixed-frame.png
ffmpeg -loglevel warning -ss 00:00:10 -i sample.mkv -vframes 1 original-frame.png
ffmpeg -loglevel warning -ss 00:00:10 -i sample-fixed.mkv -vframes 1 fixed-frame.png

echo "Sample re-encoded with saturation=$saturation."
echo "Original size: $(du -h sample.mkv | cut -f1)"
echo "Fixed size: $(du -h sample-fixed.mkv | cut -f1)"

echo "Frames extracted: ./original-frame.png and ./fixed-frame.png"
