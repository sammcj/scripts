#!/bin/bash
# Outputs the status of nvidia card utilisation

echo "Output is also being logged to /var/log/nvtop.log"

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/var/log/nvtop.log 2>&1

nvidia-smi -q -g 0 -d UTILIZATION -l | tee -a /dev/fd/3
