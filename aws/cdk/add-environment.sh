#!/usr/bin/env bash
#
# Takes a search term and a desired term and copies files sidewise with the new term in place of the old term, then offers to update text within the new files.
#
# Usage: ./add-environment.sh --search=foo --copy-to=bar --path=/some/directory

# Set the default values
search="foo"
copy_to="bar"
path="."

# Loop through the arguments
for arg in "$@"; do
  case $arg in
  --search=*)
    search="${arg#*=}"
    shift
    ;;
  --copy-to=*)
    copy_to="${arg#*=}"
    shift
    ;;
  --path=*)
    path="${arg#*=}"
    shift
    ;;
  --exclude=*)
    exclude="${arg#*=}"
    shift
    ;;
  *)
    echo "Unknown argument: $arg"
    exit 1
    ;;
  esac
done

files=($(find "$path" -type f -name "*$search*" -print))
regex="${file//$search/$copy_to/}"

if [[ -n $exclude ]]; then
  for file in "${files[@]}"; do
    if [[ $file =~ $exclude ]]; then
      echo "Excluding $file"
      unset "files[$file]"
    fi
  done
fi

echo "The following files will be copied:"
for file in "${files[@]}"; do
  echo "$file" "->" "${file//$search/$copy_to}"
done

read -p "Do you want to continue? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  for file in "${files[@]}"; do
    cp "$file" "$regex"
  done
fi

read -p "Do you want to replace the search term in the newly created files? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  for file in "${files[@]}"; do
    sed -i "s/$search/$copy_to/g" "$regex"
  done
fi
