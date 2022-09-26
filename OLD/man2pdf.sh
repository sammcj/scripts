#!/bin/sh
echo "Enter Man page to be converted"
read NAME

# Create pdf of man page
man -t $NAME | ps2pdf - $NAME.pdf > /dev/null 2>&1

#Move man page to $HOME/Documents
mv -v $NAME.pdf /home/samm/Downloads/
