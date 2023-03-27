#!/usr/bin/env bash
set -euo pipefail

# This is a template I use for most of my bash scripts.

### Setup variables
DEBUG=${DEBUG:-false}
CURRENT_TIMESTAMP=$(date '+%d-%m-%Y-%H%M%S')

if [ "$DEBUG" = "true" ]; then
  echo "Debug output enabled."
  set -x
fi
###

### Argument Parser ###

# Bash arg parser using getopt
GETOPT_ARGS=$(getopt -o d:,h --long debug:,help -- "$@")

# shellcheck disable=SC2181
if [ $? != 0 ]; then
  echo "Failed parsing options." >&2
  usage
  exit 1
fi

eval set -- "$GETOPT_ARGS"

while true; do
  case "$1" in
  -d | --debug)
    DEBUG="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done
###

### Functions ###
function exitWithError() {
  # Exits the script with an error message as well as updating the step summary and outputting the environment variables if debug is enabled
  ERROR_MESSAGE="$1"
  echo "$ERROR_MESSAGE" | tee >(cat >&2)

  if [ "$DEBUG" = "true" ]; then
    env
    if runningInCI; then
      echo "$ERROR_MESSAGE" >>"$GITHUB_STEP_SUMMARY"
    fi
  fi
  exit 1
}

usage() {
  echo "Usage: $0 (--debug=[true|false]) (--help)"
  echo ""
  echo "Example: $0 --debug=true"
  exit 1
}

function checkDependencies() {
  # Check if the required dependencies and environment variables are set
  COMMANDS=(
    "echo"
  )

  for COMMAND in "${COMMANDS[@]}"; do
    if ! command -v "$($COMMAND)" &>/dev/null; then
      exitWithError "$COMMAND not found. Install it and try again."
    fi
  done
}

function echoExample() {
  echo "This is an example function."
  echo "$CURRENT_TIMESTAMP"
}

function runningInCI() {
  # Returns true if the script is running in a CI environment (Github Actions, GitLab)
  if [ -n "$GITHUB_ACTIONS" ] || [ -n "$GITLAB_CI" ]; then
    return 0
  else
    return 1
  fi
}

function main() {
  checkDependencies
  echoExample
}
###

### Main ###

main
