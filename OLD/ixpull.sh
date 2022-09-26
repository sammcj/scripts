#!/bin/bash

echo "pulling git repos..."

declare -a repos=("$HOME/git/dir1/"
  "$HOME/git/dir2/"
)

for i in "${repos[@]}"; do
  cd "$i" && git pull --quiet --no-edit && git remote prune origin &>/dev/null &
done
