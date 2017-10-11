#!/bin/bash
DB=${1:-test_badchar}

echo "========================================"
echo "Start: `date`"
START="`date +%s`"
echo "========================================"

TAB_COL_ALL=$( echo "select search_for_non_utf8_columns();" | psql ${DB} | perl -ne 'print STDERR $_; if (/^ \(/ ) { s/[(),]/ /g; @x = split(/\s+/,$_); print "'\''$x[2]'\'','\''$x[3]'\''\n";}' )

echo "$TAB_COL_ALL"

echo "========================================"
echo "Initial search completed: `date`"
SEARCHDONE="`date +%s`"
echo "Search run time $(( $SEARCHDONE - $START )) seconds"
echo "========================================"
for TAB_COL in $TAB_COL_ALL; do
	echo "processing: $TAB_COL"
	psql -e ${DB} 2>&1 <<EOF | grep -v -E 'CONTEXT:|PL/pgSQL'
		SET session_replication_role = replica;
    SELECT process_non_utf8_at_column($TAB_COL);
    SET session_replication_role = DEFAULT;
EOF
done
echo "========================================"
echo "Update complete: `date`"
UPDATED="`date +%s`"
echo "Update run time $(( $UPDATED - $SEARCHDONE )) seconds"
echo "========================================"
echo "========= checking results ============="
echo "select search_for_non_utf8_columns(show_timestamps := false);" | psql ${DB}

echo "========================================"
echo "Finish: `date`"
FINISH="`date +%s`"
echo "Total run time $(( $FINISH - $START )) seconds"
echo "========================================"
