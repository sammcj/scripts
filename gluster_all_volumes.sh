#!/bin/bash

# gluster_all_volumes.sh
# Performs actions across all volumes in a pool
# Starts ALL gluster volumes in the pool

ALL_GLUSTER_VOLUMES=$(gluster volume list)

print_help ()
{
  printf 'Usage: %s [start|stop|get <key>|set <key> <value>]\n' "$0"
  printf "\t%s\n" "start: starts all volumes in pool"
  printf "\t%s\n" "stop: stops all volumes in pool"
  printf "\t%s\n" "get <option name>: gets volume options for all volumes in pool"
  printf "\t%s\n" "set <option name> <option value>: sets volume option for all volumes in pool"
  printf "\t%s\n" "profile <volume>: runs a 60s profile of the supplied volume"
  printf "\t%s\n" "heal: starts a manual heal across all volumes in pool"
}

parse_commandline ()
{
  case "$1" in
    start)
      while read -r line; do
          echo "Starting volume $line ..."
          gluster volume start "$line"
      done <<< "$ALL_GLUSTER_VOLUMES"
      ;;
    stop)
      while read -r line; do
          echo "Stopping volume $line ..."
          gluster volume stop "$line"
      done <<< "$ALL_GLUSTER_VOLUMES"
      ;;
    get)
      while read -r line; do
          echo "Getting option $2 on volume $line ..."
          gluster volume get "$line" "$2"
      done <<< "$ALL_GLUSTER_VOLUMES"
      ;;
    set)
      while read -r line; do
          echo "Setting $2 $3 on volume $line ..."
          gluster volume set "$line" "$2" "$3"
      done <<< "$ALL_GLUSTER_VOLUMES"
      ;;
    heal)
      while read -r line; do
          echo "Issuing manual heal on volume $line ..."
          gluster volume heal "$line"
      done <<< "$ALL_GLUSTER_VOLUMES"
      ;;
    profile)
      echo "Running 60 second profile on volume $2 ..."
      gluster volume profile "$2" start
      gluster volume profile "$2" info > "/var/tmp/gluster-profile-60s-$2"
      sleep 60
      gluster volume profile "$2" stop
      echo "60s profile of volume $2 output to /var/tmp/gluster-profile-60s-$2"
      ;;
    ""|*)
      echo "FATAL ERROR: Got an unexpected argument '$1'"
      print_help
      ;;
  esac
}

parse_commandline "$@"