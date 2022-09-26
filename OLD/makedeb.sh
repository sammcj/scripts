#!/bin/bash
echo "Usage: makedeb packagename directory"
fpm -s dir -t deb -n "$1" -v 1.0 $2
