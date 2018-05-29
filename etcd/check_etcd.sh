#!/usr/bin/env bash

# Simple Nagios / Icinga check local etcd member health (API v3)

OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Use etcd API v3
export ETCDCTL_API=3

# Check overall cluster health

# Set output of commands to variables
HEALTH_CMD="etcdctl endpoint health"
MESSAGE=$($HEALTH_CMD)

# If the node isn't healthy exit critical
if echo "$MESSAGE" | grep -v "127.0.0.1:2379 is healthy:"; then
  echo "CRITIAL: ${MESSAGE}"
  exit $CRITCAL
fi

# RETURN OUTPUT TO NAGIOS
echo "OK - ${MESSAGE}"
exit $OK