#!/usr/bin/env bash
set -euo pipefail
# Generates markdown badges for a list of GitHub repos
# This script works, but it's not pretty.

inputs=()
filter=${filter:-}
output=
output_file=${output_file:-dashboard.md}
temp_workflow=${temp_workflow:-tmp/workflow.yaml}
debug=:${debug:-false}

mkdir -p tmp/
touch tmp/output.md
touch "$output_file"

usage() {
  cat <<EOF
usage: GITHUB_TOKEN=1234abcd ${0##*/} -o OUTFILE
          [-i FILE] [-f FILTER] [-h]

    -i  input file path
    -o  output markdown file path
    -f  regex filter workflows by name (e.g. -f "build|test")
    -h  display this help

example: GITHUB_TOKEN=1234abcd ${0##*/} -o dashboard.md -i repos.txt -f "deploy|build"
EOF
  exit 1
}

debug() {
  if [ "$debug" = true ]; then
    echo "debug is enabled"
    set -x
  fi
}

urlencode() {
  # urlencode <string> - URL-encodes string and writes it to stdout
  for ((i = 0; i < "${#1}"; i++)); do
    local c="${1:i:1}"
    case $c in
    [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
    *) printf '%%%02X' "'$c" ;;
    esac
  done
}

isurl() {
  # isurl <string> - returns 0 if string is a URL, 1 otherwise
  [[ "$1" =~ https?://* ]]
}

writeout() {
  # writeout <string> - appends string to output
  output="$output""$1"
}

filterworkflows() {
  # filterworkflows <string> - checks if a string matches a provided case insensitive regex
  [[ "$1" =~ $2 ]] && return 0 || return 1
}

parse_repo() {
  # parse_repo <string> - parses a repo string and writes markdown to output
  repo="https://github.com/$1"
  repotmp="$tmpd/$1"
  reponame=${repo##*/}

  writeout "## [${reponame}](${repo})\n\n"
  rm -rf "$repotmp"
  git clone --bare "$repo" "$repotmp" 2>/dev/null

  count=0
  while read -r workflow; do
    # trap any errors and continue
    trap 'continue' ERR

    # skip non-workflow files
    [[ "$workflow" != *.yaml ]] && [[ "$workflow" != *.yml ]] && continue

    # If the filter variable is set, skip any workflows that don't match the filter
    [ -n "${filter:-}" ] && ! filterworkflows "$workflow" "$filter" && continue

    curl --header "Authorization: token ${GITHUB_TOKEN}" "https://raw.githubusercontent.com/$1/main/${workflow}" -o "$temp_workflow"
    name=$(yq '.name' "$temp_workflow")

    # set name to filename if not set
    [ -z "$name" ] && name="$workflow"

    # encode name for URL
    encoded_name="$(urlencode "$name")"

    # Output the markdown using the workflow name instead of the filename
    writeout "- [![${name}](${repo}/workflows/${encoded_name}/badge.svg)]"

    # Add a link to the workflow
    writeout "(${repo}/actions?query=workflow:\"$encoded_name\")\n"
    count=$((count + 1))
  done < <(git -C "$repotmp" ls-tree -r HEAD | awk '{print $4}' | grep '^.github/workflows/')

  # reset trap
  trap - ERR

  [ $count -eq 0 ] && writeout "(none)"
  writeout "\n\n"
  echo " Generated markdown for $1"
  echo -e "$output" >tmp/output.md
  rm -rf "$temp_workflow"
}

# if no arguments are provided, print usage
[ "$#" -lt 4 ] && usage

checkdeps() {
  # Check that all required commands and variables are available
  # Check that GITHUB_TOKEN is set
  [ -z "${GITHUB_TOKEN:-}" ] && {
    echo "GITHUB_TOKEN is not set"
    exit 1
  }

  # check for required commands
  command -v yq >/dev/null || {
    echo "Need yq"
    exit 1
  }
}

# parse arguments
OPTIND=1
while getopts ":ho:f:i:" opt; do
  case $opt in
  i)
    inputs+=("$OPTARG")
    ;;
  o)
    output_file="$OPTARG"
    ;;
  f)
    filter="$OPTARG"
    ;;
  *)
    usage
    ;;
  esac
done

main() {
  # The main program

  checkdeps

  # if the output file doesn't end in .md, append it
  [[ "$output_file" != *.md ]] && output_file="$output_file".md

  # create temp directory
  tmpd="$(mktemp -d -t dashboardXXXX)"

  for i in "${inputs[@]}"; do
    # trap any errors and continue
    trap 'continue' ERR

    echo "Generating markdown for ${i##*/}..."
    [ -n "${filter:-}" ] && echo "Filtering by '$filter'"

    title=${i##*/}
    title=${title%.*}
    writeout "# ${title}\n\n"
    count=0

    # parse the list of repos
    while read -r line; do
      [[ "$line" = \#* ]] && continue
      [ -z "$line" ] && continue
      parse_repo "$line"
      count=$((count + 1))
    done < <(if isurl "$i"; then curl -sL "$i"; else cat "$i"; fi)
    [ $count -eq 0 ] && {
      echo "Failed to read $i"
      exit 1
    }
    writeout "\n---\n"
  done
  # reset trap
  trap - ERR

  # Check if the output file exists, if it does, check if it's different from the generated output
  if [ -f "$output_file" ]; then
    if ! cmp -s "$output_file" tmp/output.md; then
      echo "Changes detected, updating $output_file"
    else
      echo "No changes detected, not updating $output_file"
      rm -rf "$tmpd" tmp/
      exit 0
    fi
  fi

  echo -e "$output" >"$output_file"

  echo "Wrote to ${output_file}"
  rm -rf $tmpd tmp/
}

# Run
main
