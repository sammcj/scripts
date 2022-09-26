#!/bin/bash
# convert .flac to .mp3 recursively
# By Glen Hewlett
#####################################
if [ -z $1 ]; then
  echo Give target directory
  exit 0
fi
find "$1" -depth -name '*' | while read file; do
  directory=$(dirname "$file")
  oldfilename=$(basename "$file")
  newfilename=$(basename "${file%.[Ff][Ll][Aa][Cc]}")
  if [ "$oldfilename" != "$newfilename" ]; then
    ffmpeg -i "$directory/$oldfilename" -ab 320k "$directory/$newfilename.mp3" </dev/null
  #rm "$directory/$oldfilename"
  fi
done
