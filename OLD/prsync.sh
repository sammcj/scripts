#!/bin/bash

# SETUP OPTIONS
export SRCDIR=$1    # "/Volumes/RAID10/music"
export DESTDIR=$2   # "/Volumes/bigdata/music"
export THREADS="8"

# RSYNC TOP LEVEL FILES AND DIRECTORY STRUCTURE
rsync -lptgoDvzd "$SRCDIR" "$DESTDIR"

# FIND ALL FILES AND PASS THEM TO MULTIPLE RSYNC PROCESSES
#cd "$SRCDIR" || exit; find . -type f -print0 | xargs -n1 -P$THREADS -I% rsync -r -numeric-ids -e "ssh -T -o Compression=no -x" % "$DESTDIR"%

cd $SRCDIR; find . -type f | xargs -n1 -P$THREADS -I% rsync -r %remotehost:/$DESTDIR/%


