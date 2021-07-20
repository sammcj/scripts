#!/bin/bash
set -euo pipefail

# This is a disgusting shell script to loop over all NewRelic apps and write their name and throughput (RPM) to a file.
# Use at your own peril.

# Date to start the average throughput from
# Note: macOS is bsd based, so you need to use -v -Xd rather than --date=-X days
START_DATE=$(date -v-30d +%F)

# create CSV to write to (exist if exists)
touch throughput.csv

# Get applications
curl -X GET 'https://api.newrelic.com/v2/applications.json' \
  -H "Api-Key:${NEWRELIC_APIKEY}" | jq -r '.applications | .[] | [.id, .name] | @tsv' | \
  while IFS=$'\t' read -r APPID APPNAME; do
    {
      echo -n -e "Application\t$APPNAME"
      echo -n -e "\tThroughput\t"
      
    # Get throughput
    curl -s -X GET "https://api.newrelic.com/v2/applications/${APPID}/metrics/data.json" \
        -H "X-Api-Key:${NEWRELIC_APIKEY}" \
        -d "names[]=HttpDispatcher&from=${START_DATE}&values[]=requests_per_minute&summarize=true" | \
        jq -r '.metric_data.metrics|.[].timeslices|.[].values.requests_per_minute'
    } >> throughput.csv
  done

echo "Done, please check throughput.csv"
