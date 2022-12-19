#!/usr/bin/env bash

freshclam -v

mkdir -p "${HOME}/CLAMAV/INFECTED"
touch "${HOME}/CLAMAV/INFECTED/infected.txt"


clamscan --verbose -r -l "${HOME}/INFECTED/infected.txt" --bell -i /Applications
clamscan --verbose -r -l "${HOME}/INFECTED/infected.txt" --bell -i "$HOME"

# Delete the infected.txt file if it is empty
if [ ! -s "${HOME}/INFECTED/infected.txt" ]; then
    rm "${HOME}/INFECTED/infected.txt"
fi

