#!/bin/bash

# /etc/network/check-not-up.sh
# checks to make sure the IP doesn't already exist before bringing the interface up

ping $1 -c 1 >/dev/null
pingres=$?
if [ $pingres == 0 ]; then
  exit 1
else
  exit 0
fi