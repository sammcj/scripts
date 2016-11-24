#!/bin/bash

rsync --size-only --no-owner --no-group --no-perms --ignore-existing --exclude *.DS_Store --numeric-ids -vrm -e "ssh -T -o Compression=no -x" /Users/samm/Library/Application\ Support/Steam root@nas:/mnt/btrfs/steam_backup/
