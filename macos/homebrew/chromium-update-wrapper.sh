#!/bin/bash

set -e

# Define constants
BACKUP_DIR="/Users/samm/Library/Mobile Documents/com~apple~CloudDocs/Backups/LittleSnitch"
MAX_BACKUPS=5
CHROMIUM_APP="/Applications/Chromium.app"
LS_CONFIG_FILE="/Library/Application Support/Objective Development/Little Snitch/Configuration.user.xpl"

# Function to check if a command executed successfully
check_command() {
    if [ $? -ne 0 ]; then
        echo "An error occurred while executing the previous command."
        exit 1
    fi
}

# Function to create backup of a file with a timestamp
create_backup() {
    local filename="$1"
    local backup_filename="${filename}_$(date +%Y%m%d%H%M%S)"
    cp "$filename" "$backup_filename"
    check_command
    echo "$backup_filename"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup Little Snitch configuration if it exists
if [ -f "$LS_CONFIG_FILE" ]; then
    ls_backup=$(create_backup "$LS_CONFIG_FILE")

    # Remove old backups if more than the maximum allowed
    num_backups=$(ls "$BACKUP_DIR"/ls_config_*.xpl 2>/dev/null | wc -l | xargs)
    if [ "$num_backups" -gt "$MAX_BACKUPS" ]; then
        oldest_backup=$(ls "$BACKUP_DIR"/ls_config_*.xpl -t 2>/dev/null | tail -n +$((MAX_BACKUPS + 1)))
        rm $oldest_backup
    fi
else
    echo "Little Snitch configuration file not found. Skipping backup..."
fi

# Backup macOS Firewall global state
fw_globalstate_backup=$(create_backup "$BACKUP_DIR/fw_globalstate.txt")

# Backup macOS Firewall application rules
fw_apps_backup=$(create_backup "$BACKUP_DIR/fw_apps.txt")

# Set Little Snitch to allow inbound and outbound connections for Chromium.app
sudo /usr/bin/sed -i '' "s|$CHROMIUM_APP.*|$CHROMIUM_APP ALLOW|" "$ls_backup"

# Set macOS Firewall to deny incoming connections to Chromium.app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add "$CHROMIUM_APP"

# Clear extended attributes for Chromium.app
sudo xattr -c "$CHROMIUM_APP"

echo "Configuration completed successfully."
