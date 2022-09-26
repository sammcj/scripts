#!/bin/bash
echo "Usage: makerpm packagename directory"

# Check if rpm-build, squashfs-tools are installed, if not offer to install them
if ! rpm -q rpm-build squashfs-tools rubygems >/dev/null; then
  echo "rpm-build and squashfs-tools rubygems are required to build an RPM"
  echo "Would you like to install them? (y/n)"
  read answer
  if [ "$answer" != "${answer#[Yy]}" ]; then
    sudo yum install -y rpm-build squashfs-tools rubygems
  else
    echo "Aborting..."
    exit 1
  fi
fi

# Check if fpm is installed, if not offer to install it from rubygems
if ! rpm -q fpm >/dev/null; then
  echo "fpm is required to build an RPM"
  echo "Would you like to install it? (y/n)"
  read answer
  if [ "$answer" != "${answer#[Yy]}" ]; then
    gem install fpm
  else
    echo "Aborting..."
    exit 1
  fi
fi

fpm -s dir -t rpm -n "$1" -v 1.0 "$2"
