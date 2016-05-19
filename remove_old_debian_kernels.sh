#!/bin/bash
# Removes all debian kernels that are not the currently running version

INSTALLED_KERNELS=$(dpkg --list | grep -c linux-image)
RUNNING_KERNEL=$(uname -r)

echo
echo "----------------------------------"
echo "Number of installed kernels: $INSTALLED_KERNELS"
echo "Running kernel: $RUNNING_KERNEL"
echo "----------------------------------"
echo

dpkg --list | grep -i linux-image | grep -v "$(uname -r)" | awk '{ print $2}' | xargs apt-get purge -y

INSTALLED_KERNELS=$(dpkg --list | grep -c linux-image)
echo
echo "----------------------------------"
echo "Number of installed kernels: $INSTALLED_KERNELS"
echo "--------------csb-----------------"
echo
