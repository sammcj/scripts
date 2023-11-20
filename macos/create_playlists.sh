#!/bin/bash

# Directory where M3U files will be stored
output_dir="./playlists"
mkdir -p "$output_dir"

# Process the output from AppleScript
while IFS= read -r line; do
  if [[ $line == Playlist:* ]]; then
    playlist_name=$(echo "$line" | cut -d' ' -f2-)
    current_playlist="$output_dir/$playlist_name.m3u"
    echo "#EXTM3U" >"$current_playlist"
  elif [[ $line == Loved* ]]; then
    current_playlist="$output_dir/Loved_Tracks.m3u"
    echo "#EXTM3U" >"$current_playlist"
  else
    echo "$line" >>"$current_playlist"
  fi
done < <(osascript create_playlists.applescript)

echo "Playlists created in $output_dir"
