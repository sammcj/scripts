#!/bin/sh

echo "Removes (recursively) all files of the extension you pass the script"
echo "Usage: rmall png"
find . -type f -name "*.$1" -exec rm -i {} \;
