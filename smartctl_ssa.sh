#!/usr/bin/env bash
# smartctl_ssa.sh
# Automatically maps SATA Disk Names to their HP SmartArray Bay numbers for use with smartctl.

set -eou pipefail

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

# print usage
usage() {
  echo "Usage: smartctl_ssa.sh <device> <command>"
  echo "Example: smartctl_ssa.sh /dev/sda -a          # Outputs all smart info"
  echo "Example: smartctl_ssa.sh /dev/sda -H          # Outputs the health status"
  echo "Example: smartctl_ssa.sh /dev/sda -t short    # Starts a short smart test"
  echo "Example: smartctl_ssa.sh /dev/sda -l selftest # Outputs the last time a smart test was run"
}
# pass the command to run, the disk and any parameters to smartctl, if no command is given default to using run_command_on_disk

# Get the list of all disks on the controller, and output the bay and block device name
all_disks() {
  ssacli ctrl first pd all show detail | grep -Ee 'Disk Name' -Ee 'Bay' | awk '{print $1 $2 $3}' | paste - - | sed 's/\t/ /' | awk -F " |:" '{print $2, $4}' | sort
}

# Return the bay number for a given disk name
get_bay() {
  all_disks | grep -E "$1" | awk '{print $1}'
}

# Run a smartctl command against a disk name, automatically determining the bay number
smartctl_command() {
  while read -r line; do
    bay=$(echo "$line" | awk '{print $1}')
    disk=$(echo "$line" | awk '{print $2}')
    # echo "smartctl -a -d cciss,${bay} ${disk}"
    echo "Running command $1 on disk ${disk} in bay ${bay}"
    $1 -d cciss,$bay $disk
  done <<<"$(all_disks)"
}

# Take a disk by name and run any smartctl parameter against it (e.g. run_command_on_disk /dev/sda -t short)
run_command_on_disk() {
  disk=$1
  shift
  bay=$(get_bay $disk)
  echo -e "[Running command: smartctl $* -d cciss,$bay $disk]\n"
  smartctl "$@" -d cciss,"$bay" "$disk"
}

run_command_on_disk "$@"
