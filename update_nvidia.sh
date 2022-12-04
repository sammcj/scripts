#!/usr/bin/env bash

# This script gets the latest nvidia AMD64 driver from the nvidia website, downloads it, and installs it.
# It ensure that CentOS 7's devtoolset-11 is used for the latest supported GCC etc...
# Then it runs nvidia-patch to patch the driver for the stream concurrency limit.

# Set the log file location
log_file="/var/log/update_nvidia.log"

# Timestamp for the log files
timestamp=$(date)

# Fetch the latest version number of the NVIDIA Linux AMD64 graphics driver from the download page
driver_version_number=$(curl -s 'https://www.nvidia.com/Download/processFind.aspx?psid=101&pfid=817&osid=12&lid=2&whql=&lang=en-us&ctk=0&qnfslb=01' | grep -o "[0-9]\{1,\}.[0-9]\{1,\}.[0-9]\{1,\}.[0-9]\{1,\}" | sort -r | head -n 1)

# Generate the URL for the driver download
driver_url="https://uk.download.nvidia.com/XFree86/Linux-x86_64/$driver_version_number/NVIDIA-Linux-x86_64-$driver_version_number.run"

# Download the driver
aria2c -q "$driver_url"

# Make the downloaded file executable
chmod +x "NVIDIA-Linux-x86_64-$driver_version_number.run"

# Enable devtoolset-11
source /opt/rh/devtoolset-11/enable

# Install the driver silently without a UI
# Install the driver silently without a UI
./"NVIDIA-Linux-x86_64-$driver_version_number.run" --ui=none -a -q

# Clone the nvidia-patch repository if it doesn't already exist
if [ ! -d "nvidia-patch" ]; then
  git clone https://github.com/keylase/nvidia-patch.git
fi

# Navigate to the nvidia-patch directory
cd nvidia-patch || exit

# Pull the latest changes from the Git repository
git pull

# Run the patch script
./patch.sh

# Write the log output to the log file
echo "$timestamp: NVIDIA driver update completed successfully" >>$log_file
echo "$timestamp: NVIDIA driver version: $driver_version_number" >>$log_file
echo "$timestamp: NVIDIA driver installation log: /var/log/nvidia-installer.log" >>$log_file
echo "$timestamp: nvidia-patch log: nvidia-patch/patch.log" >>$log_file
