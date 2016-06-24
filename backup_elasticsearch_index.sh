#!/bin/bash
#
# See https://www.elastic.co/guide/en/elasticsearch/reference/1.7/modules-snapshots.html
#
INDEX="${INDEX:=kibana-int}"
BACKUPDIR="${BACKUPDIR:='/var/backup/es'}"
ESCONFIG="${ESCONFIG:='/etc/elasticsearch/ES1/elasticsearch.yml'}"
ESHOST="${ESHOST:=localhost}"

# # Exit on error
trap "exit 0" SIGTERM

# # Ensure the backup directory exists
mkdir -p "${BACKUPDIR}${INDEX}"

# # Ensure the backup dir is in the elasticsearch config
# grep -q $BACKUPDIR $ESCONFIG

CreateBackupPool()
{
# Create the ES backup pool
curl -XPUT "http://$ESHOST:9200/_snapshot/kibana_backups" -d "{
    \"type\": \"fs\",
    \"settings\": {
        \"location\": \"$INDEX\",
        \"compress\": false
    }
}"
}

TakeSnapshot()
{
  # Take a backup
  curl -XPUT "http://$ESHOST:9200/_snapshot/kibana_backups/snapshot-name?wait_for_completion=true" -d "{
    \"indices\": \"$INDEX\",
    \"ignore_unavailable\": true,
    \"include_global_state\": false
  }"
}

CreateBackupPool
TakeSnapshot
