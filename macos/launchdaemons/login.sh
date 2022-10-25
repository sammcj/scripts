#!/usr/bin/env bash
#
# This script can be configured to run upon login with a LaunchDaemon
#
# Run this with a LaunchDaemon, copy com.login-shell-script.job.plist to /Users/YOURUSERNAMEHERE/Library/LaunchAgents/
#
# And enable it with: launchctl load -w /Users/YOURUSERNAMEHERE/Library/LaunchAgents/com.login-shell-script.job.plist

set -euo pipefail

TIMESTAMP_FORMAT=${TIMESTAMP_FORMAT:-"%F-%H%M%S"}
LOGFILE=~/Library/Logs/login-sh-$(date "+$TIMESTAMP_FORMAT").log

# Function that deletes any log files older than 90 days
function cleanup_logs() {
  find ~/Library/Logs -name "login-sh-*.log" -mtime +90 -exec rm {} \;
}

# Function that checks if there is a log file with todays date (ignoring the time), if it does exit 0 with a message that the script has already run today
# Use a loop as if doesn't support globs
function check_if_already_run_today() {
  for file in ~/Library/Logs/login-sh-*.log; do
    if [[ $file == *$(date "+%F")* ]]; then
      echo "Script already run today, exiting"
      exit 0
    fi
  done
}

# Function that runs a command only if it exists
run() {
  if [[ -x "$1" ]]; then
    echo "Running $1" >>"$LOGFILE"
    "$@" >>"$LOGFILE" 2>&1
  fi
}

# Function that checks internet connectivity
check_internet() {
  if ! ping -c 2 -t 5 1.1.1.1; then
    echo "No internet connection, sleeping for 30 seconds" >>"$LOGFILE"
    sleep 30
    if ! ping -c 2 -t 5 1.1.1.1; then
      echo "No internet connection, exiting" >>"$LOGFILE"
      exit 1
    fi
  fi
}

# Redirect all stdout and stderr for files in this script to a log file
exec 1> >(tee "${LOGFILE}") 2>&1

# Exit if we've already run today
check_if_already_run_today

# Add SSH keys to the keychain
ssh-add --apple-use-keychain ~/.ssh/id_*.key

update_software() {
  # Check we have an internet connection
  check_internet

  # Update Homebrew
  logger "Updating Homebrew with login.sh"
  run brew update && brew upgrade

  # Update Mac App Store Apps
  logger "Updating Mac App Store Apps with login.sh"
  run mas upgrade

  # Update go packages
  logger "Updating go packages with login.sh"
  run run gup update
}

# Cleanup old logs
cleanup_logs

# Log a message to the macOS logs
logger "macOS login.sh script completed"
