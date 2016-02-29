#!/bin/bash
# Usage utf8_cleanup.sh <filename>
# YMMV, pull requests accepted ;)

file $1

# Remove bad carridge returns and binary rubbish
tr -cd '\11\12\15\40-\176' < $1 > "$1"_no_binary.sql

# Make sure it's a stanndard file format
dos2unix "$1"_file_no_binary.sql

# Remove non-UTF8 characters from the file
iconv -f UTF-8 -t ISO-8859-1//IGNORE --output="utf8_$1" "$1_file_no_binary.sql"

file "utf8_$1"

# Import the database
echo "You may now restore the database with something like pg_drop $1 && createdb $1 -E utf8 && psql -d $1 < "utf8_$1"
