#!/usr/bin/env bash -el

export BUMP=$1
OPTIONS=""

if [ $# -eq 0 ]; then
  echo "No arguments supplied"
  exit 255
fi

if ! command -v jq &>/dev/null; then
  echo "Please ensure you have jq installed"
  exit 255
fi

# Only allow version bumps from an up-to-date main
GIT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "${GIT_BRANCH}" != "main" ]]; then
  echo "Git branch = '${GIT_BRANCH}. Needs to be on the 'main' branch. Aborting"
  exit 255
fi
git fetch --all --tags
git pull

# Do the version bump
lerna version "$BUMP" --exact --force-publish --conventional-commits --no-git-tag-version --no-push

# Because main is protected we need to create a release branch and push the version, changelogs, and tag there
NEW_VERSION=$(lerna ll --json --loglevel silent | jq -r '.[0].version')
git checkout -b "release/${NEW_VERSION}"

# Align the package.json versions with the lerna version
sed -i '' -E 's/("version": ")([^"]+)/\1'"${NEW_VERSION}"'/g' package.json

git commit -am "chore(release): publish version ${NEW_VERSION} [skip-ci]"
git tag "v${NEW_VERSION}"
git push --set-upstream origin "release/${NEW_VERSION}"
git push
git push origin "v${NEW_VERSION}"
