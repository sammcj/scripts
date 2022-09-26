#!/bin/bash
set -euo pipefail

# This is a disgusting shell script to loop over all NewRelic apps and write their name and throughput (RPM) to a file.
# Use at your own peril.

# Date to start the average throughput from
# Note: macOS is bsd based, so you need to use -v -Xd rather than --date=-X days
START_DATE=$(date -v-30d +%F)

# Cleanup any previous output and add a heading
rm throughput.csv applications.json
echo -e "Application\tThroughput" > throughput.csv
touch applications.json

# Get applications (pageinated, defaults to a maximum of 5 pages)
for i in {1..4}
do
  curl -X GET "https://api.newrelic.com/v2/applications.json?page=$i" \
    -H "Api-Key:${NEWRELIC_APIKEY}" >> applications.json
done

jq -r '.applications | .[] | [.id, .name] | @tsv' < applications.json | \
  while IFS=$'\t' read -r APPID APPNAME; do
    {
      echo -n -e "$APPNAME\t"
      
    # Get throughput
    curl -s -X GET "https://api.newrelic.com/v2/applications/${APPID}/metrics/data.json" \
        -H "X-Api-Key:${NEWRELIC_APIKEY}" \
        -d "names[]=HttpDispatcher&from=${START_DATE}&values[]=requests_per_minute&summarize=true" | \
        jq -r '.metric_data.metrics|.[].timeslices|.[].values.requests_per_minute'
    } >> throughput.csv
  done

echo "Done, please check throughput.csv"
