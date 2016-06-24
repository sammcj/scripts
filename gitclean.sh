#!/bin/bash
#
# Loops over .git directories.
# Garbage collects and repacts the repositories improving performance and reducing size.

find . -type d -name .git -execdir /bin/bash -c "pwd; tput setaf 1; echo 'size BEFORE: $(du -sh .)'; \
    tput setaf 2; git repack -a -d -f --max-pack-size=10g --depth=500 --window=250; \
    git gc --aggressive ; tput setaf 3; echo 'size AFTER: $(du -sh .)'; tput sgr0" \;

