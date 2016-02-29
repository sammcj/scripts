#!/bin/bash
# Usage utf8_cleanup.sh <filename>
# YMMV, pull requests accepted ;)

SQL_DUMP = $1
SQL_DUMP_UTF8 = "$SQL_DUMP_UTF8"

file "$SQL_DUMP"

# Remove bad carridge returns and binary rubbish
tr -cd '\11\12\15\40-\176' < "$SQL_DUM > file_no_binary.sql

# Make sure it's a stanndard file format
dos2unix file_no_binary.sql

# Remove non-UTF8 characters from the file
iconv -f UTF-8 -t ISO-8859-1//IGNORE --output="$SQL_DUMP_UTF8" file_no_binary.sql

file "$SQL_DUMP_UTF8 "

# Import the database
pg_restore -c -F t -f ""$SQL_DUMP_UTF8"
