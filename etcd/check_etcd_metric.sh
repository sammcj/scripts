#!/usr/bin/env bash

# Simple Nagios / Icinga check a metric from etcd's prometheus API

METRIC="$1"
OK_VALUE="$2"

# https://github.com/coreos/etcd/blob/master/Documentation/op-guide/monitoring.md#metrics-endpoint
METRIC_URL="http://localhost:2379/metrics"

# Nagios exist codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

CHECK_STRING=$(curl -L ${METRIC_URL} | grep -Ev 'debugging|^#' | grep ${METRIC})
CHECK_OUTPUT=$(echo $CHECK_STRING)

if $? -eq 1 -; then
  echo "CRITIAL: ${CHECK_STRING}"
  exit $CRITCAL
fi

# RETURN OUTPUT TO NAGIOS
echo "OK - ${CHECK_STRING}"
exit $OK