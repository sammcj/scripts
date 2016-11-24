#!/bin/bash
echo "Usage: makerpm packagename directory
fpm -s dir -t rpm -n "$1" -v 1.0 $2
