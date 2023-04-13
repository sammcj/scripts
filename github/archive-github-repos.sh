#!/usr/bin/env bash

# Get the user's Github API token from environment or input
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Please enter your Github API token:"
  read -s GITHUB_API_TOKEN
else
  GITHUB_API_TOKEN=$GITHUB_TOKEN
fi

# Get the user's Github username
echo "Please enter your Github username:"
read GITHUB_USERNAME

# Define the output file for the logs
OUTPUT_FILE="github_repo_report_$(date +%Y%m%d_%H%M%S).txt"

# Function to fetch repositories
fetch_repositories() {
  curl -s -H "Authorization: token $GITHUB_API_TOKEN" "https://api.github.com/users/$GITHUB_USERNAME/repos?type=$1" | jq -c '.[] | {name: .name, created_at: .created_at, updated_at: .updated_at, pushed_at: .pushed_at, commits_url: .commits_url, archive_url: .archive_url}'
}

# Fetch repositories
echo "Fetching your repositories..."
REPOS_OWNER=$(fetch_repositories "owner")
REPOS_MEMBER=$(fetch_repositories "member")

# Combine repositories
REPOS="$REPOS_OWNER$REPOS_MEMBER"

# Check if there are any repositories
if [ -z "$REPOS" ]; then
  echo "No repositories found. Exiting script."
  exit 1
fi

# Function to fetch the number of commits for a repository
fetch_commit_count() {
  COMMIT_COUNT=$(curl -s -H "Authorization: token $GITHUB_API_TOKEN" "$1" | jq '. | length')
  echo $COMMIT_COUNT
}

# Add commit count to each repository
REPOS_WITH_COMMIT_COUNT=""
for repo in $REPOS; do
  COMMIT_COUNT=$(fetch_commit_count "$(echo $repo | jq -r '.commits_url')")
  REPO_WITH_COUNT=$(echo $repo | jq ". + {\"commit_count\": $COMMIT_COUNT}")
  REPOS_WITH_COMMIT_COUNT+="$REPO_WITH_COUNT"$'\n'
done

# Function to sort repositories
sort_repositories() {
  echo "$REPOS_WITH_COMMIT_COUNT" | jq -s "sort_by(.$1)" | jq -c '.[]'
}

# Filter and sort repositories
echo "Please choose an attribute to sort by (created_at, pushed_at, commit_count):"
read ATTRIBUTE

# Error handling for invalid attribute
case "$ATTRIBUTE" in
"created_at" | "pushed_at" | "commit_count")
  SORTED_REPOS=$(sort_repositories "$ATTRIBUTE")
  ;;
*)
  echo "Invalid attribute. Exiting script."
  exit 1
  ;;
esac

# Display sorted repositories
echo "Sorted repositories:"
echo "$SORTED_REPOS" | jq -r '.name'

# Select repositories to archive
echo "Please enter the names of the repositories you want to archive, separated by spaces:"
read -a REPO_NAMES

for repo_name in "${REPO_NAMES[@]}"; do
  REPOS_SELECTED+=$(echo "$REPOS_WITH_COMMIT_COUNT" | jq -c "select(.name == \"$repo_name\")")$'\n'
done

# Archive repositories
echo "Are you sure you want to archive the selected repositories? (y/n)"
read CONFIRM_ARCHIVE

if [ "$CONFIRM_ARCHIVE" == "y" ]; then
  for repo in $(echo "$REPOS_SELECTED" | jq -r '.name'); do
    ARCHIVE_URL=$(echo "$REPOS_SELECTED" | jq -r "select(.name == \"$repo\") | .archive_url")
    curl -s -X PUT -H "Authorization: token $GITHUB_API_TOKEN" -H "Accept: application/vnd.github+json" "$ARCHIVE_URL"
    echo "Repository '$repo' has been archived."
  done
  echo "Repositories archived."
else
  echo "Archiving cancelled. Exiting script."
  exit 0
fi

# Log output to file
exec &> >(tee -a "$OUTPUT_FILE")
echo "Logging output to $OUTPUT_FILE"

exit 0
