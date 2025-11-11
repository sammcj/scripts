#!/usr/bin/env bash

# Assumes you have an alias to read the custom locate database like so: alias locate='locate -d ~/.locatedb'

/usr/bin/find / \
  \( -path /tmp -o \
     -path /var/tmp -o \
     -path /private/tmp -o \
     -path "/Volumes/TimeMachine2TB-SATA" -o \
     -path "/Volumes/com.apple.TimeMachine.localsnapshots" -o \
     -path /System -o \
     -path /private/var/folders -o \
     -path /Library/Caches -o \
     -path /private/var/vm -o \
     -path /private/var/log -o \
     -path /cores -o \
     -path "*/node_modules" -o \
     -path "*/.venv" -o \
     -path "*/venv" -o \
     -path "*/__pycache__" -o \
     -path "*/.cache" -o \
     -path "*/.git" -o \
     -path "*/.hg" -o \
     -path "*/.svn" -o \
     -path "*/vendor" -o \
     -path "*/.next" -o \
     -path "*/.nuxt" -o \
     -path "*/.Trash" -o \
     -path "*/Library/Caches" \
  \) -prune -o -print 2>/dev/null | \
  /usr/libexec/locate.mklocatedb > "$HOME/.locatedb"

   #   -path /usr/sbin -o \
   #   -path "*/target" -o \
   #   -path "*/build" -o \
   #   -path "*/dist" -o \
   #   -path "/Library/Application Support/Apple" -o \
   #   -path "/Library/Application Support/Google" -o \
   #   -path /Library/Preferences -o \
