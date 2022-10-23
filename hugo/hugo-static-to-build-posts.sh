#!/usr/bin/env bash
set -euo pipefail

# This script is used to converts hugo static posts to hugo bundle posts, it creates a copy rather than modifying the original files.
#
# Usage: ./static-to-bundle.sh
#
# Author: Sam McLeod

# Path to the hugo posts directory
POSTS_DIR=content/posts

# Prompt the user to confirm the operation
read -p "This script will convert all posts in ${POSTS_DIR}/*.md to hugo bundle posts, are you sure you want to continue? [y/n] " -n 1 -r
echo

echo "Converting hugo static posts to hugo bundle posts..."

# Loop through all the markdown files in the posts directory
for file in $POSTS_DIR/*.md; do
  # Get the filename without the extension
  filename=$(basename -- "$file")
  filename="${filename%.*}"

  # Create a new directory with the same name as the post
  mkdir $POSTS_DIR/"$filename"

  # Copy the post to the new directory
  cp "$file" $POSTS_DIR/"$filename"/index.md
done

echo "migrating local images and image links"

# For each post, check for any links to images in the static/img/ directory and copy them to the post's bundle directory
for file in "$POSTS_DIR"/*/*.md; do
  # Loop through all the images in the post
  for image in $(grep -o -E "\!\[.*\]\(.*\)" "$file" | grep -o -E "\((.*)\)" | grep -o -E "[^()]+"); do
    # Check if the image is in the static/img/ directory
    if [[ $image == /img/* ]]; then
      # Copy the image to the post's bundle directory
      cp -n "static${image}" $(dirname "$file")

      # Update the image link in the post to remove the /img/ prefix, escaping any forward slashes
      sed -i '' "s|${image}|$(basename "$image")|g" "$file"
    fi
  done
done
