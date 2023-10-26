#!/usr/bin/env bash
# Combine all mp3 into a single file and convert it to m4a/m4b format for audiobooks

 
abook() {
    local DIR="${1}"

    if [[ ! -d $DIR || -z $1 ]]; then
        DIR=$(pwd)
    fi

    # generating random name
    local NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 6 | head -n 1)

    # generating book
    ls -1 "${DIR}/"*.mp3 | awk  '{printf "file |%s|\n", $0}' | \
        sed -e "s/|/\'/g" > "${DIR}/${NAME}.txt" \
        && ffmpeg -f concat -safe 0 -i "${DIR}/${NAME}.txt" -c copy "${DIR}/${NAME}.mp3" \
        && ffmpeg -i "${DIR}/${NAME}.mp3" "${DIR}/${NAME}.m4a" \
        && mv "${DIR}/${NAME}.m4a" "${DIR}/$(basename "${DIR}").m4b"

    # Cleanup
    unlink "${DIR}/${NAME}.txt"
    unlink "${DIR}/${NAME}.mp3"
}

abook "$1"
