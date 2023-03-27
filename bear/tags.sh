#!/usr/bin/env bash

config=$(jq -c '.[]' tagsconfig.json)

for item in $config; do
  # Extract the folder, tag, and pattern from the item

  folder=$(echo $item | jq -r '.folder')
  tag=$(echo $item | jq -r '.tag')

  # Check if the exact tag is present in the last 3 lines of any .md file
  for file in Bear\ Import/*.md; do
    if grep -q "$tag" "$file"; then
      # If the tag is present, move the file to the folder
      echo "Moving $file to $folder"
      mv "$file" "$folder"
    fi
  done
done
