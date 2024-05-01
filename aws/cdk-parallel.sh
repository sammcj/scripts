#!/usr/bin/env bash

# This script is used to run some CDK commands in parallel.
# It will run the commands in parallel and wait for all of them to finish before exiting.
# It will store the output of each command in a separate file in the `cdk-parallel-output` directory which should be added to the `.gitignore` file.
# The script will also print the output of each command to the console after each command finishes.

# Usage:
# ./cdk-parallel.sh synth <environment1,environment2,...>
#    e.g. ./cdk-parallel.sh synth dev,sit,prod
# ./cdk-parallel.sh diff <environment1,environment2,...>
# ./cdk-parallel.sh deploy <environment1,environment2,...>
#
# Multiple commands can be run sequentially by separating them with a comma.
#   # e.g. ./cdk-parallel.sh synth,diff dev,sit,prod

set -ex

## Variables
PIDs=()
waitTimeout=${waitTimeout:-1200} # Default timeout is 1200 seconds (20 minutes)

## Input validation

# Check if the CDK command is provided
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Please provide a CDK command to run, e.g. synth or synth,diff,deploy"
  echo "and the environments to run the command for, e.g. dev,sit"
  exit 1
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
  exit 0
fi

function usage() {
  tput setaf 2 # set colour to green
  echo "Usage:"
  echo "./cdk-parallel.sh synth <environment1,environment2,...>"
  echo "   e.g. ./cdk-parallel.sh synth dev,sit,prod"
  echo "./cdk-parallel.sh diff <environment1,environment2,...>"
  echo "   e.g. ./cdk-parallel.sh diff dev,sit,prod"
  echo "./cdk-parallel.sh deploy <environment1,environment2,...>"
  echo "   e.g. ./cdk-parallel.sh deploy dev,sit,prod"
  echo ""
  echo "Multiple commands can be run sequentially by separating them with a comma."
  echo "   e.g. ./cdk-parallel.sh synth,diff dev,sit,prod"
  tput sgr0 # reset colour
  exit 1
}

## Functions
function setup() {
  # Create the output directory if it doesn't exist
  mkdir -p cdk-parallel-output
}

function readInput() {
  # Split the command and environments
  IFS=',' read -r -a commands <<<"$1"
  IFS=',' read -r -a environments <<<"$2"
}

function runCommands() {
  # Run commands in parallel
  for command in "${commands[@]}"; do
    for environment in "${environments[@]}"; do
      output_file="cdk-parallel-output/${command}-${environment}.log"
      cdk "${command}" "${environment}" >"${output_file}" 2>&1 &
      PIDs+=($!)
      tpud setaf 4 # set colour to blue
      echo "Running 'cdk ${command} ${environment}' in the background. Output will be saved to ${output_file}"
      tput sgr0 # reset colour
    done
  done
}

function timeout() {
  # Wait for the commands to finish
  timeout=$waitTimeout
  echo "Waiting for the commands to finish. Timeout: ${timeout} seconds"
  sleep "${timeout}"
  echo "Timeout reached. Exiting..."
  exit 1
}

function waitForPID() {
  PID=$1
  # wait for the PID to finish in the background
  wait "$PID" || {
    tput setaf 1 # set colour to red
    echo "PID $PID failed with exit code $?"
    tput sgr0 # reset colour
    exit 1
  }
}

function waitForAllPIDs() {
  # Wait for all the PIDs to finish, as soon as one any one finishes, print the output from the corresponding file then go back to waiting
  for PID in "${PIDs[@]}"; do
    trap 'kill $PID' EXIT # Kill all the PIDs if the script is interrupted
    waitForPID "$PID"
    output_file="cdk-parallel-output/${command}-${environment}.log"
    echo "Output for 'cdk ${command} ${environment}':"
    cat "${output_file}"
  done
}

## Main
function main() {
  setup
  readInput "$@"
  runCommands
  waitForAllPIDs
}

## Entrypoint
main "$@"
