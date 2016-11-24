#!/bin/bash
# http://askubuntu.com/questions/108043/how-can-i-convert-my-flac-music-collection-to-apple-lossless

#shopt -s globstar

for f in ./**/*.flac;
  do parallel avconv -i "$f" -c:a alac "${f%.*}.m4a" && rm "$f";
done
