#!/bin/bash

# Remove non-en languages (-100MB~)
localedef --list-archive | grep -v -i ^en | xargs localedef --delete-from-archive
mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
build-locale-archive

yum remove -y iwl* wpa_supplicant.x86_64 alsa-firmware.noarch

yum clean all