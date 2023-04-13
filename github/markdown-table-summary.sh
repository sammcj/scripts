#!/usr/bin/env bash

# A markdown table generator for Github Actions (but could easily be used anywhere that has bash).
# It takes environment variable names and outputs their name and value as a markdown table.
# It also takes an optional environment variable called ADDITIONAL_OUTPUTS which is a comma separated list of K=V pairs to add to the table.
#
# Usage example:
#  steps:
#    - name: Generate Markdown Table
#      id: generate-markdown-table
#      env:
#        SOME_VAR1: "value1"
#        SOME_VAR2: "value2"
#        SOME_VAR3: "value3"
#        ADDITIONAL_OUTPUTS: "INPUT_AWS_ACCOUNT_ID=1234,INPUT_AWS_REGION=ap-southeast-2"
#      run: ./markdown-table-summary.sh
#
# Example output:
#  Step Summary
#
#  | Job Summary | 2021-03-01 12:00:00 |
#  | --- | --- |
#  | SOME_VAR1 | value1 |
#  | SOME_VAR2 | value2 |
#  | SOME_VAR3 | value3 |
#  | INPUT_AWS_ACCOUNT_ID | 1234 |
#  | INPUT_AWS_REGION | ap-southeast-2 |

set -oe pipefail

env_vars=(
  SOME_VAR1
  SOME_VAR2
  SOME_VAR3
)

function markdown_table() {
  # Initialize the table with headers
  markdown_table="| Job Summary | $(TZ=':Australia/Melbourne' date) |\n| --- | --- |\n"

  # Generate the markdown table
  # Loop through the rows and update the table with their corresponding environment variables, ignore any empty values
  for i in "${!rows[@]}"; do
    row=${rows[$i]}
    env_var=${env_vars[$i]}
    value=${!env_var}
    if [ -n "$value" ]; then
      markdown_table+="| $row | $value |\n"
    fi
  done

  # If the environment variable $ADDITIONAL_OUTPUTS contains a string -
  # split it into an array of K=V pairs and append the key to the rows and value env_vars arrays.
  # e.g. "INPUT_AWS_ACCOUNT_ID=1234,INPUT_AWS_REGION=ap-southeast-2", ignore any with empty values
  if [ -n "$ADDITIONAL_OUTPUTS" ]; then
    IFS=',' read -ra additional_outputs <<<"$ADDITIONAL_OUTPUTS"
    for additional_output in "${additional_outputs[@]}"; do
      IFS='=' read -ra output <<<"$additional_output"
      key=${output[0]}
      value=${output[1]}
      if [ -n "$value" ]; then
        rows+=("$key")
        env_vars+=("$value")
        markdown_table+="| $key | $value |\n"
      fi
    done
  fi

  # Loop through any environment variables starting with INPUT_ and add them to the table
  for env_var in $(env | grep -E '^INPUT_' | cut -d '=' -f 1); do
    value=${!env_var}
    if [ -n "$value" ]; then
      rows+=("$env_var")
      env_vars+=("$value")
      markdown_table+="| $env_var | $value |\n"
    fi
  done

  # To add any other useful information to the table, you can append it here, e.g:
  # markdown_table+="| Runner Uptime | $(uptime) |\n"
}

markdown_table

# Output the completed markdown table to the step summary
#shellcheck disable=SC2129
echo -e "Step Summary \n" >>"$GITHUB_STEP_SUMMARY"
echo -e "$markdown_table" >>"$GITHUB_STEP_SUMMARY"
