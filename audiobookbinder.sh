#!/usr/bin/env bash

# Use ffmpeg to convert a directory of mp3 files into a m4b audiobook, splitting at 950mb, ensuring that the chapters are correct, that the cover art is included and that its same quality as the original mp3s.

# Usage: audiobookbinder.sh <directory>
# Tested on macOS

# Requirements:
# ffmpeg
# mp3info
# mp3val
# mp3splt
# mp3wrap
# id3v2

# Set the directory to the first argument
directory="$1"

# Set the output file name to the directory name
output="$(basename "$directory")"

# Set the cover art to the first jpg in the directory
cover="$(find "$directory" -type f -name "*.jpg" -print -quit)"

# Detect if the existing mp3 have cover art
if [ -z "$(mp3info -p "%g" "$directory"/*.mp3)" ]; then
  # If not, add the cover art
  id3v2 -a "$cover" "$directory"/*.mp3
fi

# Detect if the existing mp3 have chapters
if [ -z "$(mp3info -p "%c" "$directory"/*.mp3)" ]; then
  # If not, add the chapters
  mp3splt -a -d "$directory" "$directory"/*.mp3
fi

# Convert the mp3s to m4b
ffmpeg -i "$directory"/%02d.mp3 -i "$cover" -map 0:0 -map 1:0 -c copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "$output".m4b

# Validate the m4b
mp3val -f "$output".m4b

# Split the m4b at 950mb
mp3splt -a -s -b 950 "$output".m4b

# Wrap the m4b
mp3wrap "$output".m4b "$output"_split_*.m4b

# Remove the split files
rm "$output"_split_*.m4b

# Output a summary
echo "Summary:"
echo "Cover: $cover"
echo "Output: $output.m4b"
echo "Size: $(du -h "$output".m4b | cut -f1)"
