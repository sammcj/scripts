#!/bin/bash

rsync --size-only --no-owner --no-group --no-perms --ignore-existing --exclude *.DS_Store --numeric-ids --delete-after -vrm -e "ssh -T -o Compression=no -x" /Volumes/2TB_RAID/music/ root@nas:/mnt/btrfs/music/
