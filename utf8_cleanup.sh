#!/usr/bin/env bash

# Usage utf8_cleanup.sh <filename>

file "$1" | grep -q "UTF-8" && {
  echo "File is already UTF-8"
  exit 1
}

# Remove bad carriage returns and binary rubbish
tr -cd '\11\12\15\40-\176' <"$1" >"$1"_clean

# Make sure it's a stannard file format
dos2unix "$1"_clean

# Remove non-UTF8 characters from the file
iconv -f UTF-8 -t ISO-8859-1//IGNORE --output="utf8_$1" "$1_clean"

file "utf8_$1"
