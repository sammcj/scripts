#!/bin/bash

echo '#!/bin/bash'
echo ''
echo 'failed_items=""'
echo 'function install_package() {'
echo 'echo EXECUTING: brew install $1 $2'
echo 'brew install $1 $2'
echo '[ $? -ne 0 ] && $failed_items="$failed_items $1"  # package failed to install.'
echo '}'

brew tap | while read tap; do echo "brew tap $tap"; done

brew list | while read item;
do
  echo "install_package $item '$(brew info $item | /usr/bin/grep 'Built from source with:' | /usr/bin/sed 's/^[ \t]*Built from source with:/ /g; s/\,/ /g')'"
done

echo '[ ! -z $failed_items ] && echo The following items were failed to install: && echo $failed_items'
