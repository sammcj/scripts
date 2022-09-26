#!/bin/bash
#
# Removes a brick that's currently a replica and re-adds it as an arbiter only volume
#
# Usage: ./gluster_convert_replica_to_arbiter_brick.sh [VOLUME] [VOLUMEPATH] [ARBITERHOST]
# E.g.:  ./gluster_convert_replica_to_arbiter_brick.sh my_vol /mnt/volumes int-gluster-03.my.house.com
#

export VOLUME=$1
export VOLUMEPATH=$2
export ARBITERHOST=$3

echo y | gluster volume remove-brick $VOLUME replica 2 $ARBITERHOST:$VOLUMEPATH/$VOLUME force

setfattr -x trusted.glusterfs.volume-id $VOLUMEPATH/$VOLUME; setfattr -x trusted.gfid $VOLUMEPATH/$VOLUME; rm -rf $VOLUMEPATH/$VOLUME

gluster volume add-brick $VOLUME replica 3 arbiter 1 $ARBITERHOST:$VOLUMEPATH/$VOLUME
