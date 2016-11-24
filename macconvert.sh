#!/bin/bash

rm -rf /tmp/output.tmp
echo $1 | tr '[a-z]' '[A-Z]' | tr -d ";" | tr -d ":" | tr -d "-" > /tmp/output.tmp

clear
echo ""
echo "*****************"
cat /tmp/output.tmp
echo "TNET-$(cat /tmp/output.tmp)-0001"
cat /tmp/output.tmp | xclip
chmod 777 /tmp/output.tmp
echo ""

