#!/usr/bin/env bash
set -eo pipefail

# This script uses aws cli to add tags to a filtered set of s3 objects in a given bucket
#
# Usage: ./add-cdk-tags.sh -b '<bucket-name>' -k <tag-key> -v <tag-value> -f <filter> -c <concurrency>
#
# Author: Sam McLeod (2022-10-18)

usage() {
  echo "Usage: ./add-cdk-tags.sh -b '<bucket-name>' -k <tag-key> -v <tag-value> -f <filter> [-c <concurrency> (default: 8)]"
  exit 1
}

# bash argparser
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  -b | --bucket)
    BUCKET_NAME="$2"
    shift
    shift
    ;;
  -f | --filter)
    FILTER="$2"
    shift
    shift
    ;;
  -k | --key)
    TAG_KEY="$2"
    shift
    shift
    ;;
  -v | --value)
    TAG_VALUE="$2"
    shift
    shift
    ;;
  -c | --concurrency)
    CONCURRENCY="${2:-8}"
    shift
    shift
    ;;
  *)
    echo "Unknown argument $1"
    usage
    exit 1
    ;;
  esac
done

if [[ -z "$BUCKET_NAME" || -z "$TAG_KEY" || -z "$TAG_VALUE" || -z "$FILTER" ]]; then
  usage
fi

OBJECTS=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --query "Contents[?!contains(Key, '$FILTER')].Key" --output text)
echo "Ignore objects with filter ${FILTER}"

# shellcheck disable=SC2031,SC2030
printObjects() {
  (
    for OBJECT in $OBJECTS; do
      ((i = i % CONCURRENCY))
      ((i++ == 0)) && wait
      echo "Current tags for object '${OBJECT}':"
      aws s3api get-object-tagging --bucket "$BUCKET_NAME" --key "$OBJECT" --query "TagSet[?Key=='$KEY'].Value" --output text &
    done && fg
  )
}

# shellcheck disable=SC2031
addTags() {
  (
    for OBJECT in $OBJECTS; do
      ((i = i % CONCURRENCY))
      ((i++ == 0)) && wait
      echo "Adding tag to object '$OBJECT'"
      aws s3api put-object-tagging --bucket "$BUCKET_NAME" --key "$OBJECT" --tagging "TagSet=[{Key=${TAG_KEY},Value=${TAG_VALUE}}]" &
    done && fg
  )
  echo "Done!"
}
printObjects

echo "Adding tag '${TAG_KEY}' with value '${TAG_VALUE}' to all objects in bucket '${BUCKET_NAME}'"
read -p "Continue adding/replacing tags? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
else
  addTags
fi
