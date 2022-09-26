#!/bin/bash
# disable lro

for i in $(ls -A /sys/class/net); do ethtool -k "$i" | grep large-receive-offload; done

for i in $(ls -A /sys/class/net); do ethtool -K "$i" lro off; done
