#!/usr/bin/env bash

function usage {
  echo "./$(basename $0) -h --> shows usage"
}

# list of arguments expected in the input
optstring=":h"

while getopts ${optstring} arg; do
  case ${arg} in
  h)
    echo "showing usage!"
    usage
    ;;
  :)
    echo "$0: Must supply an argument to -$OPTARG." >&2
    exit 1
    ;;
  ?)
    echo "Invalid option: -${OPTARG}."
    exit 2
    ;;
  esac
done
