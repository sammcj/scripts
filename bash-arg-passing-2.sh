#!/usr/bin/env bash
set -euo pipefail

function usage {
  echo "./$(basename $0) -h --help --> shows usage"
  echo "./$(basename $0) -o --one --> prints Option One"
}

# print usage if no arguments are passed
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

# -: adds double dash long options
while getopts ":oh-:" opt; do
  case $opt in
  h)
    usage
    exit 0
    ;;
  o)
    echo "Option One"
    exit 0
    ;;
  -)
    case "${OPTARG}" in
    help)
      usage
      exit 0
      ;;
    one)
      echo "Option One"
      exit 0
      ;;
    *)
      echo "Invalid option: --${OPTARG}" >&2
      exit 1
      ;;
    esac
    ;;
  \?)
    echo "Invalid option: -${OPTARG}" >&2
    exit 1
    ;;
  :)
    echo "Option -${OPTARG} requires an argument." >&2
    exit 1
    ;;
  esac
done
