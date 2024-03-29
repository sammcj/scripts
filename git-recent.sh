#!/usr/bin/env bash

set -euo pipefail

# git-recent.sh
# list all local branches, sorted by last commit, formatted nicely

branch='%(color:yellow)%(refname:short)%(color:reset)'
spacer='%(color:black) %(color:reset)'

COUNT=0
while getopts "n:" opt; do
  case ${opt} in
  n)
    if ! [[ $OPTARG =~ ^[0-9]{1,}$ ]]; then
      echo "-n should be an integer."
      exit 1
    fi
    COUNT=${OPTARG}
    shift
    ;;
  *)
    echo "Invalid option: -${OPTARG}" 1>&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

format="\
%(HEAD) \
$branch|\
%(color:bold red)%(objectname:short)%(color:reset) \
%(color:bold green)(%(committerdate:relative))%(color:reset) \
%(color:bold blue)%(authorname)%(color:reset) \
%(color:yellow)%(upstream:track)%(color:reset)
$spacer|\
%(contents:subject)
$spacer|"

lessopts="--tabs=4 --quit-if-one-screen --RAW-CONTROL-CHARS --no-init"

git for-each-ref \
  --color=always \
  --count=$COUNT \
  --sort=-committerdate \
  "refs/heads/" \
  --format="$format" |
  column -ts '|' |
  less "$lessopts"

# The above command:
#   for all known branches,
#   (force colouring on this, especially since it's being piped)
#   optionally, specify the number of branches you want to display
#   sort descending by last commit
#   show local branches (change to "" to include both local + remote branches)
#   apply the formatting template above
#   break into columns
#   use the pager only if there's not enough space
