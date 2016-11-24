#!/bin/bash
DATABASE=$1

# Check it is an SQLITE3 database first, if not exit
file "$DATABASE" | grep -q "SQLite 3.x database"
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

sqlite3 "$DATABASE" "VACUUM;";
