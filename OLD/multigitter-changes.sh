#!/usr/bin/env bash

# For use with multi-gitter - https://github.com/lindell/multi-gitter

# Usage:
#
# $ multi-gitter run ~/git/scripts/multigitter-changes.sh -O my-org -m "Commit message" -B branch-name
#
# Dry run:
# $ multi-gitter run ~/git/scripts/multigitter-changes.sh --dry-run --log-level=debug -O my-org -m "Commit message" -B branch-name

### String replacement
# find . -type f -exec sed -i 's/mymatchingword/myreplacementword/g' {} \;
