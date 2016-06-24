#!/bin/bash
for f in *.flac; do ffmpeg -i "$f" -acodec alac "${f%.flac}.m4a"; done
