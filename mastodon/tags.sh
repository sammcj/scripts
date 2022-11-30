#!/usr/bin/env bash

# This script is for interacting with Mastodon tags via the API, it:
# 1. Uses a provided MASTODON_ACCESS_TOKEN to authenticate with the API.
# 2. Returns a list of followed tags and saves them to a JSON file. (https://docs.joinmastodon.org/methods/followed_tags/).
# 3. Offers to add a new tag to the list of followed tags. (https://docs.joinmastodon.org/methods/tags/#follow).

# Usage: MASTODON_ACCESS_TOKEN=<token> ./tags.sh [backup|add]

BACKUP_FILENAME="followed_tags_$(date +%Y%m%d).json"
INSTANCE="aus.social"

function get_tags() {
  # use the Mastodon API to get a list of followed tags with the $MASTODON_ACCESS_TOKEN for authentication, pipe to jq to get the "name" and save to a JSON file.
  echo -e "$(curl -s -H "Authorization: Bearer ${MASTODON_ACCESS_TOKEN}" "https://${INSTANCE}/api/v1/followed_tags")"
}

function follow_tag() {
  curl -s -H "Authorization: Bearer ${MASTODON_ACCESS_TOKEN}" -X POST -d "name=$1" "https://${INSTANCE}/api/v1/tags/${1}/follow"
}

function tag_info() {
  curl -s -H "Authorization: Bearer ${MASTODON_ACCESS_TOKEN}" "https://${INSTANCE}/api/v1/tags/${1}"
}

function upload_json() {
  read -rp "Enter the path to the JSON file containing the tags to follow: " json_file
  while IFS= read -r tag; do
    follow_tag "$tag"
  done <"$json_file"
}

function compare_tags() {
  ls -1 followed_tags*.json
  read -rp "Enter the path to the JSON file containing the tags to compare: " json_file
  while IFS= read -r tag; do
    tag_info "$tag"
  done <"$json_file"
  current_tags="$(get_tags | jq -r '.[] | .name')"
  echo -e "\n---"
  echo -e "diff of current tags and $json_file:"
  diff <(echo "$current_tags") <(echo "$json_file")

}

if [ "$2" ]; then
  tag="$2"
fi

if [ "$1" = "backup" ]; then
  get_tags | jq -r '.[] | .name' >"$BACKUP_FILENAME"
  echo -e "Followed tags saved to ${BACKUP_FILENAME}"
elif [ "$1" = "add" ]; then
  read -p "Enter a tag to follow: " tag
  follow_tag "$tag"
  echo -e "Followed tag: $tag"
  tag_info "$tag" | jq -r '.[] | .name'
elif [ "$1" = "info" ]; then
  if [ -z "$tag" ]; then
    echo "Please provide a tag to get info for."
    read -p "Enter a tag to get info on: " tag
  fi
  tag_info "$tag"
elif [ "$1" = "compare" ]; then
  compare_tags
elif [ "$1" = "upload" ]; then
  upload_json
else
  echo -e "Usage: MASTODON_ACCESS_TOKEN=<token> ./tags.sh [backup|add|info|compare|upload]"
fi
