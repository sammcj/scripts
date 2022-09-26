#!/usr/bin/env bash
#
# Drops a db and recreates it from a plain text sql file
#
# Author: Sam McLeod 25/1/2015
# Tested with PostgreSQL 9.4
#

SRC_DB=$1
DEST_DB=$2
SQL_FILE=$3

set -o nounset
set -o errexit

if [ -n "$SRC_DB" ] && [ -n "$DEST_DB" ] && [ -s "$SQL_FILE" ]; then
  echo "Current active connections to the database:"
  psql -c "SELECT * FROM pg_stat_activity where datname = '$DEST_DB';"
else
  echo "Usage: replacedb <src_database_name> <dst_database_name> <pg_dump_file.sql>"
  exit 1
fi

echo ""
echo "WARNING: THIS ACTION IS DESTRUCTIVE AND IRREVERSIBLE!"
read -r -p "If you sure you want to DROP the destination database please type [$DEST_DB] " response

case $response in
$DEST_DB)
  logger "replacedb replacing the database $DEST_DB with content from $SQL_FILE"
  set -x
  psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity where pg_stat_activity.datname = '$DEST_DB';"
  dropdb "$DEST_DB"
  createdb -E UTF8 "$DEST_DB"
  sed -e "s/$SRC_DB/$DEST_DB/" "$SQL_FILE" | psql "$DEST_DB"
  ;;
*)
  echo "No changes made, exiting..."
  exit
  ;;
esac
