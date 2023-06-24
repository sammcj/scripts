#!/usr/bin/env bash

# This script will create a backup of the Plex preferences file if it is not empty.
# If the file is empty, it will restore the most recent backup and restart the Plex container.
#
# 0 1 * * * /path/to/this/script/backup-prefs.sh

# Variables
FILE_TO_CHECK="/opt/docker-data/plex/Library/Application Support/Plex Media Server/Preferences.xml"
BACKUP_DIR="/opt/docker-data/plex/Library/Application Support/Plex Media Server/"
COMMAND_TO_RUN_IF_EMPTY="docker restart plex"
MIN_SIZE=1 # Size in kilobytes
MAX_DAYS=60

# Extract the filename without extension
FILENAME=$(basename -- "$FILE_TO_CHECK")
FILENAME="${FILENAME%.*}"

# Get the file size in kilobytes
FILE_SIZE=$(du -k "$FILE_TO_CHECK" | cut -f1)

# If the file size is greater than the minimum size, create a backup
if [[ $FILE_SIZE -gt $MIN_SIZE ]]; then
  DATE_EXT=$(date '+%Y-%m-%d')
  cp "$FILE_TO_CHECK" "$BACKUP_DIR/$FILENAME.$DATE_EXT"
  MESSAGE="Plex Preferences backup created: $BACKUP_DIR/$FILENAME.$DATE_EXT"
  echo "$MESSAGE" | logger -p info
else
  # If the file size is 0, restore the most recent backup and run a command
  if [[ $FILE_SIZE -eq 0 ]]; then
    MOST_RECENT_BACKUP=$(find "$BACKUP_DIR" -name "$FILENAME.*" -type f -printf '%T+ %p\n' | sort -r | head -n1 | cut -f2- -d' ')
    MESSAGE="Preferences.xml is empty! Restoring $MOST_RECENT_BACKUP and running $COMMAND_TO_RUN_IF_EMPTY"
    echo "$MESSAGE" | logger -p error
    echo
    cp "$MOST_RECENT_BACKUP" "$FILE_TO_CHECK"
    $COMMAND_TO_RUN_IF_EMPTY
  fi
fi

# Remove backup files older than MAX_DAYS
OLD_BACKUPS=$(find "$BACKUP_DIR" -name "$FILENAME.*" -mtime +$MAX_DAYS -type f)
if [[ -n $OLD_BACKUPS ]]; then
  echo "$OLD_BACKUPS" | xargs rm
  logger -p info "Removed backups older than $MAX_DAYS days"
fi
