#!/usr/bin/env bash

# This script will fetch a list of all your Github repositories, wait for you to remove any you wish to keep, then archive the rest.

# check if hub is installed
if ! command -v hub &>/dev/null; then
  echo "hub could not be found (brew install hub)"
  exit
fi

# check if jq is installed
if ! command -v jq &>/dev/null; then
  echo "jq could not be found (brew install jq)"
  exit
fi

# check hub is logged in
if ! hub api user &>/dev/null; then
  echo "hub is not logged in"
  exit
fi

# prompt the user for the Github username
echo "Enter your Github username:"
read USERNAME

# hub api --paginate "users/$USERNAME/repos" | jq -r '.[]."full_name"' >repo_names.txt

gh repo list --no-archived --limit 144 --json nameWithOwner --jq ".[].nameWithOwner" >repo_names.txt

# --visibility public
# --fork
echo "Go through repo_names.txt manually, remove any repositories you don't want to archive"
echo "Press any key to continue or Ctrl-C to abort"

open repo_+names.txt

echo "Are you ready to continue? (y/n)"
read ANSWER

if [ "$ANSWER" != "y" ]; then
  echo "Aborting"
  exit 1
fi

cat repo_names.txt

echo "are you sure you want to archive all these repositories? (YES/*)"
read ANSWER

if [ "$ANSWER" == "YES" ]; then
  cat repo_names.txt | xargs -I {} -n 1 hub api -X PATCH -F archived=true /repos/{}
else
  echo "Aborting"
  exit 1
fi

echo "Repositories archived"
echo "Remaining repositories:"
hub api --paginate "users/$USERNAME/repos" | jq -r '.[] | select(.archived==false) | .full_name'

# deletion:
# while read -r line; do
#     gh repo delete $line --yes
# done < delete_these_repos.txt
