#!/usr/bin/env bash

set -e

# https://gist.github.com/RickyCook/dfcc13846e5b97a4a484e54d3d1ec18f

### CONFIG

CONTAINER_NAME="$(date %Y-%m-%d-%H-%M-%S)"
CONTAINER_IMAGE=python:3.9 # must have bash, or change the infinite sleep on :17
COMMAND_PREFIX=./pants

### STOP EDITING

THISDIR="$(cd "$(dirname "$0")"; pwd)"

docker container inspect "$CONTAINER_NAME" 2>&1 >/dev/null || docker container create \
    --name "$CONTAINER_NAME" \
    --volume "$THISDIR:/work" \
    "$CONTAINER_IMAGE" \
    bash -c 'while true; do sleep 1; done' \
    >/dev/null

function on_exit() {
    local exit_code=$?
    docker container kill "$CONTAINER_NAME" >/dev/null
    exit $exit_code
}

trap on_exit EXIT

docker container start "$CONTAINER_NAME" >/dev/null
docker container exec \
    --interactive \
    --tty \
    --workdir /work \
    "$CONTAINER_NAME" \
    "$COMMAND_PREFIX" "$@"

