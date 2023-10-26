#!/usr/bin/env bash

# This is a template I use for most of my bash scripts.

# Only enable these shell behaviours if we're not being sourced
if ! (return 0 2>/dev/null); then
  # A better class of script...
  set -o errexit  # Exit on most errors (see the manual)
  set -o nounset  # Disallow expansion of unset variables
  set -o pipefail # Use last non-zero exit code in a pipeline
fi

### Setup variables
currentTimestamp=$(date '+%d-%m-%Y-%H%M%S')
scriptDir="$(dirname "$scriptPath")"
scriptName="$(basename "$scriptPath")"

readonly DEBUG=${DEBUG:-false}
readonly origCWD="$PWD"
readonly scriptParams="$*"
readonly scriptPath="${BASH_SOURCE[0]}"
readonly scriptDir scriptName currentTimestamp

if [ "$DEBUG" = "true" ]; then
  echo "Debug output enabled."
  set -o xtrace # Trace the execution of the script

  echo "Script name: $scriptName"
  echo "Script path: $scriptPath"
  echo "Script dir: $scriptDir"
  echo "Script params: $scriptParams"
  echo "Current timestamp: $currentTimestamp"
  echo "Original CWD: $origCWD"

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
      exitWithError "${COMMAND} not found. Install it and try again."
    fi
  done
}

function echoExample() {
  echo "This is an example function."
  echo "$currentTimestamp"
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
