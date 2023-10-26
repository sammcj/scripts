#!/usr/bin/env bash
set -e

# Sam's dodgy wrapper for bees / beesd (https://github.com/Zygo/bees)

# @reboot cron job
# @reboot CRON=true /path/to/script

# If we were launched from cron, sleep for a bit to avoid a thundering herd
if [ -n "$CRON" ]; then
  sleep 60
fi

function youarenothingtome() {
  # lowest CPU and IO priority
  schedtool -D -n20 $$
  ionice -c3 -p $$
}

function start() {
  fs="$1"
  echo "Logging to /var/log/bees-${fs}.log"
  echo "beesd status can be found in /var/run/bees/${fs}.status"
  mv /var/log/bees-"${fs}".log /var/log/bees-"${fs}".log.1 || true
  touch /var/log/bees-"${fs}".log
  beesd -v1 "$fs" >>/var/log/bees-"${fs}".log 2>&1 &
}

function killahbeez() {
  fs="$1"
  echo "Stopping beesd for $fs..."
  killall bees && sleep 2 || true
  echo "Unmounting $fs..."
  umount "$fs"
  ps -ef | grep -i bees | grep -v grep
}

## MAIN
if [ "$1" == "stop" ] || [ "$1" == "--stop" ]; then
  echo "stopping..."
  killahbeez /run/bees/mnt/de4e6126-2801-42f3-9283-2450f97a8708
  killahbeez /run/bees/mnt/ec5a7836-5287-4c9a-a9bd-6ce235d16ee4
else
  youarenothingtome
  start "de4e6126-2801-42f3-9283-2450f97a8708"
  start "ec5a7836-5287-4c9a-a9bd-6ce235d16ee4"
fi
