#!/usr/bin/env bash

# A shell script that generates a complete CHANGELOG.md file from git commits and tags.
# Usage: ./generate-changelog.sh <tag-pattern> [changelog-file]
# Example: ./generate-changelog.sh "v[0-9]*" CHANGELOG.md

set -e

# A shell script that generates a complete CHANGELOG.md markdown file from git commits and tags with git tags as the headings, containing the git commit messages.

# The pattern that tags must match to be included, defaults to semver tags without words after the last digit (e.g. v1.2.3 but NOT v1.2.3-beta.4)
TAG_PATTERN="v[0-9+].[0-9+].[0-9]"

# The file to write the changelog to, defaults to CHANGELOG.md
CHANGELOG_FILE="CHANGELOG.md"

# Recreate the changelog file
echo -e "# Changelog\n" >$CHANGELOG_FILE

# Get the tags
TAGS="$(git tag -l --sort=-creatordate "$TAG_PATTERN")"

# Get the first tag
FIRST_TAG=$(echo "$TAGS" | tail -n 1)
LAST_TAG=$(echo "$TAGS" | head -n 1)

echo -e "[Generated changelog from $LAST_TAG to $FIRST_TAG]\n" >>$CHANGELOG_FILE

# Generate a changelog from the git tags and commits
generate_changelog() {

  while read -r TAG; do

    # Use git log to get the previous tag before the current tag or return the SHA of the first commit if it's the first tag
    PREVIOUS_TAG=$(git describe --tags "$TAG"^ --match "$TAG_PATTERN" 2>/dev/null || git rev-list --max-parents=0 HEAD 2>/dev/null)

    # Get the tag message
    TAG_MESSAGE=$(git tag -l --format='%(contents)' "$TAG")

    # Get the date the current tag was created
    TAG_DATE=$(git log -1 --format=%cd --date=short "$TAG")

    # Use git log to get all commits between the current tag and the previous tag and deduplicate them unless the previous tag is the first tag
    TAG_COMMITS=$(git log --pretty=format:'- %ad - '%s' - %an' --date=short --reverse "$PREVIOUS_TAG".."$TAG" | sort -u)
    echo -e "## (${TAG}) - ${TAG_DATE} - ${TAG_MESSAGE}\n" >>"$CHANGELOG_FILE"
    echo "$TAG_COMMITS" >>"$CHANGELOG_FILE"

    echo "" >>"$CHANGELOG_FILE"

  done <<<"$TAGS"

  # Get any git commits from git log that were created before the first tag
  PRE_TAGGED_COMMITS=$(git log --pretty=format:'- %ad - '%s' - %an' --date=short --reverse "$LAST_TAG"^..HEAD | sort -u)

  # If there are commits before the first tag, add them to the changelog
  if [ -n "$PRE_TAGGED_COMMITS" ]; then
    echo -e "## Commits before the first tag (${FIRST_TAG})\n" >>"$CHANGELOG_FILE"
    echo "$PRE_TAGGED_COMMITS" >>"$CHANGELOG_FILE"
  fi

}

# Generate the changelog
generate_changelog

cat "$CHANGELOG_FILE"

