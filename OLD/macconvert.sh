#!/bin/bash

# This script converts MAC addresses to the format required

TMPFILE=$(mktemp /tmp/macconvert.XXXXXX)

echo $1 | tr '[a-z]' '[A-Z]' | tr -d ";" | tr -d ":" | tr -d "-" >"$TMPFILE"

clear
echo ""
echo "*****************"
cat /tmp/output.tmp
echo "TNET-$(cat /tmp/output.tmp)-0001"
cat "$TMPFILE" | xclip
echo ""
