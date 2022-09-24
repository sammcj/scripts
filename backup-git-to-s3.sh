#!/usr/bin/env bash
set -eo pipefail

# Compress and backup a git repository directory repo to S3

# Usage
# BUCKET="my-s3-bucket" ./backup-git-to-s3.sh

## Environment Variables ##

#BUCKET=undef
PREFIX="${PREFIX:=githubRepoBackup}"
REPOSITORY=${REPOSITORY:=$(printf '%s\n' "${PWD##*/}")}
REPOSITORY_PATH=${REPOSITORY_PATH:="./"}
TEMP_DIR="${TEMP_DIR:=/tmp}"
TAR_COMMAND="${TAR_COMMAND:=tar -czvf}"
S3_REGION=${S3_REGION:="ap-southeast-2"}

DATE=$(date '+%Y%m%d%H%M%S')
FILENAME="${REPOSITORY}-${DATE}.tar.gz"
FILEPATH="${TEMP_DIR}/${FILENAME}"
S3_URL="s3://${BUCKET}/${PREFIX}/${FILENAME}"

## Functions ##

usage() {
  echo "Usage: BUCKET=my-s3-bucket ./backup-git-to-s3.sh"
  echo "Environment Variables:"
  echo "  BUCKET: S3 bucket name"
  echo "  PREFIX: S3 prefix (default: githubRepoBackup)"
  echo "  S3_REGION: S3 region (default: ap-southeast-2)"
  echo "  REPOSITORY: Repository name (default: current directory name)"
  echo "  REPOSITORY_PATH: Repository path (default: ./)"
  echo "  TEMP_DIR: Temporary directory (default: /tmp)"
  echo "  TAR_COMMAND: tar command (default: tar -czvf)"
  exit 1
}

function exit_error {
  echo "$1"
  cleanup
  exit 1
}

function cleanup {
  rm -f "$FILEPATH"
}

## Operations ##

# check if BUCKET is set
if [ -z "$BUCKET" ]; then
  usage
fi

echo "Compressing ${REPOSITORY_PATH} as ${FILEPATH}..."
$TAR_COMMAND "$FILEPATH" $REPOSITORY_PATH || exit_error "Failed to create tar file"

if [ -f "$FILEPATH" ]; then
  echo "Backing up ${REPOSITORY} from ${REPOSITORY_PATH} as ${FILEPATH} to ${S3_URL} in region ${S3_REGION}"
  aws s3 cp "$FILEPATH" "$S3_URL" --region "$S3_REGION" || exit_error "Error uploading ${FILEPATH} to ${S3_URL} in region ${S3_REGION}"
fi

echo "Succesfully backed up ${REPOSITORY}"

cleanup
