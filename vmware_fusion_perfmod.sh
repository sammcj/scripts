#!/bin/bash
#
# Loops over VMware VMs found in the passed directory.
# Modifies disk and memory settings to improve performance.
# Tweaks taken mostly from http://artykul8.com/2012/06/vmware-performance-enhancing/
#
# USE AT YOUR OWN RISK!

VMDIR=$1

find . -type f -name .vmx -execdir /bin/bash -c "pwd; tput setaf 1; echo 'size BEFORE: $(du -sh .)'; \
    tput setaf 2; git repack -a -d -f --max-pack-size=10g --depth=500 --window=250; \
    git gc --aggressive ; tput setaf 3; echo 'size AFTER: $(du -sh .)'; tput sgr0" \;

# mainMem.backing = "swap"

# Tweak: Choose the right disk controller and specify SSD
# Instead of the latest SATA AHCI controller choose LSI Logic SAS controller with SCSI disk for Windows guest OS, or PVSCSI for other types of OS.
# Unfortunately SATA AHCI on VMware has the lowest performance out of the three controllers and highest CPU overhead (see the references on the topic at the end).
# In addition to choosing the right controller, if your host disk is SSD you can explicitly specify the disk type as SSD to guest OS.

scsi0:0.virtualSSD = 1

# Tweak: Disable log files for VM
logging = "FALSE"

# Disable memory trimming:
MemTrimRate = "0"

# Disable page sharing:
sched.mem.pshare.enable = "FALSE"

#Disable scale down of memory allocation:
MemAllowAutoScaleDown = "FALSE"

# Memory allocation configuration:
prefvmx.useRecommendedLockedMemSize = "TRUE"
