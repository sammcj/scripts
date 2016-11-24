#!/bin/bash -e
# Sam McLeod 2016
# Alerts if more the n number of kernels are installed

MAX_KERNELS=$1

if [[ -f /etc/debian_version ]] ; then
  INSTALLED_KERNELS=$(dpkg --list | grep -c linux-image)
else
  INSTALLED_KERNELS=$(rpm -qa | grep -cE 'kernel-ml-[0-9]|kernel.x86_64')
fi

if (( $INSTALLED_KERNELS > $MAX_KERNELS )) ; then
  echo "WARNING: Number of installed kernels: $INSTALLED_KERNELS"
  exit 1
fi

echo "OK: $INSTALLED_KERNELS kernels installed"
exit 0