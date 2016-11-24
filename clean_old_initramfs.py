#!/usr/bin/python
#
# This script cleans up initramfs leftovers from uninstalled kernels.
# Can be run automatically or manually at any time
#

import os

BOOT_DIR = '/boot'

kernel_list = []
ramfs_list = []
file_list = os.listdir(BOOT_DIR)

for item in file_list:
  if 'vmlinuz' in item:
    kernel_list.append(item)
  elif 'initramfs' in item:
    ramfs_list.append(item)

for item in ramfs_list:
  pattern = 'vmlinuz-%s' % item[10:].replace('.img', '').replace('kdump', '')
  if pattern not in kernel_list:
    os.unlink("%s/%s" % (BOOT_DIR, item))
