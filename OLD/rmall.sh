#!/bin/sh

echo "Removes (recursively) all files of the extension you pass the script"
echo "Usage: rmall png"

# prompt user to confirm they wish to continue
echo "Are you sure you want to continue to recursively delete all $1 files? (y/n)"
read answer

if [ "$answer" != "${answer#[Yy]}" ]; then
  find . -type f -name "*.$1" -exec rm -i {} \;
else
  echo "Aborting..."
fi
