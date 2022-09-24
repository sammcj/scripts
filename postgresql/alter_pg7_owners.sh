#!/bin/bash -x

usage()
{
cat << EOF
usage: $0 options

This script sets ownership for all tables, sequences, views, and functions for a given schema.
Run this script as your postgres OS user.

Credit: Based on http://stackoverflow.com/a/2686185/305019 by Alex Soto
        Also merged changes from @sharoonthomas

bspkrs: Added function code based on http://dba.stackexchange.com/a/9710/31043
        and changed messy object quoting to use quote_ident().

sammcj: Added added create user and setting the database owership to that user

OPTIONS:
   -h      Show this message
   -d      Database name
   -o      New Owner
   -s      Schema (defaults to public)
EOF
}

DB_NAME="";
NEW_OWNER="";
SCHEMA="public";
while getopts "hd:o:s:" OPTION; do
    case $OPTION in
        h)
            usage;
            exit 1;
            ;;
        d)
            DB_NAME=$OPTARG;
            ;;
        o)
            NEW_OWNER=$OPTARG;
            ;;
        s)
            SCHEMA=$OPTARG;
            ;;
    esac
done

if [[ -z $DB_NAME ]] || [[ -z $NEW_OWNER ]]; then
     usage;
     exit 1;
fi

`psql -qAt -c "create user ${NEW_OWNER}"`
`psql -qAt -c "ALTER DATABASE ${DB_NAME} OWNER TO ${NEW_OWNER}"`

# Using the NULL byte as the separator as its the only character disallowed from PG table names
IFS=\0;
for tbl in `psql -qAt -R\0 -c "SELECT quote_ident(schemaname) || '.' || quote_ident(tablename) FROM pg_catalog.pg_tables WHERE schemaname = '${SCHEMA}';" ${DB_NAME}` \
           `psql -qAt -R\0 -c "SELECT quote_ident(sequence_schema) || '.' || quote_ident(sequence_name) FROM information_schema.sequences WHERE sequence_schema = '${SCHEMA}';" ${DB_NAME}` \
           `psql -qAt -R\0 -c "SELECT quote_ident(table_schema) || '.' || quote_ident(table_name) FROM information_schema.views WHERE table_schema = '${SCHEMA}';" ${DB_NAME}` ;
do
    psql -c "ALTER TABLE $tbl OWNER TO ${NEW_OWNER}" ${DB_NAME};
done

for func in `psql -qAt -R\0 -c "SELECT quote_ident(n.nspname) || '.' || quote_ident(p.proname) || '(' || pg_catalog.pg_get_function_identity_arguments(p.oid) || ')' FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = '${SCHEMA}';" ${DB_NAME}` ;
do
    psql -c "ALTER FUNCTION $func OWNER TO ${NEW_OWNER}" ${DB_NAME};
done
unset IFS;