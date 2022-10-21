#!/usr/bin/env bash
set -eo pipefail
# github-branch-protection.sh
# Author: Sam McLeod @sammcj
#
# This script is used to backup, create, or delete branch protection rules on Github.
# It uses the Github GraphQL API to query and manipulate branch protection rules.
#
# The required graphql schema and specific protection rules is defined in the file github-branch-protection.graphql
# Defaults:
#       allowsDeletions: false
#       allowsForcePushes: false
#       dismissesStaleReviews: true
#       isAdminEnforced: false
#       pattern: $branchPattern
#       repositoryId: $repositoryId
#       requiresApprovingReviews: true
#       requiredApprovingReviewCount: 1
#       requiresCodeOwnerReviews: true
#       requiredStatusCheckContexts: $requiredStatusChecks
#       requiresStatusChecks: true
#       restrictsReviewDismissals: false
#
# https://cli.github.com/manual/gh_api_graphql
# https://docs.github.com/en/graphql/reference/objects#branchprotectionrule
#
# TODO:
# - Add ability to set Required Status Check Contexts
# This is not possible the the gh cli tool due to this Github bug - https://github.com/cli/cli/issues/1484
#
# You can add them manually via the Github UI or via a CURL request along the lines of:
# $ jq -n '{"required_status_checks":{"strict":true,"contexts":["lint-pr / lint, coverage","lint-and-test (dev, 1234567890)","build-shared (test, 2345678901)"]}}' | gh api -X PUT repos/ --input - "${OWNER}/${REPO}/branches/${branchPattern}/protection"

usage() {
  echo "Usage:
              ./github-branch-protection.sh --action [backup|create|delete]
                                            --pattern [branch pattern to match]
                                            --owner [owner of the repositories]
                                            (
                                              --repositories 'repo-1 repo-2'
                                            or
                                              --repositories-file [file containing repositories on each line]
                                            )
                                            --FORCE [true|false]
        Example:
              ./github-branch-protection.sh --action backup --pattern 'main' --owner 'myOrg' --repositories 'repo-1 repo-2'
              ./github-branch-protection.sh --action backup --pattern 'main' --owner 'myOrg' --repositories-file repositories.txt"
  exit 1
}

PARSED_ARGUMENTS=$(getopt -a -n alphabet -o a:r:p:o:f: --long action:,repositories:,pattern:,owner:,repositories-file:,FORCE -n 'github-branch-protection.sh' -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
  usage
fi

echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :; do
  case "$1" in
  -a | --action)
    ACTION="$2"
    shift
    shift
    ;;
  -r | --repositories)
    REPOS="$2"
    shift
    shift
    ;;
  -f | --repositories-file)
    REPOS_FILE="$2"
    shift
    shift
    ;;
  -p | --pattern)
    PATTERN="$2"
    shift
    shift
    ;;
  -o | --owner)
    OWNER="$2"
    shift
    shift
    ;;
  --FORCE)
    FORCE=true
    shift
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Unknown argument $1"
    usage
    exit 1
    ;;
  esac
done

if [[ -z "$ACTION" || -z "$PATTERN" || -z "$OWNER" ]]; then
  usage
fi

# Create the REPOS_ARRAY from either the REPOS variable or the REPOS_FILE
if [[ -n "$REPOS" && -z $REPOS_FILE ]]; then
  IFS=', ' read -r -a REPOS_ARRAY <<<"$REPOS"
elif [[ -f "$REPOS_FILE" && -z "$REPOS" ]]; then
  readarray -t REPOS_ARRAY <"$REPOS_FILE"
else
  echo "You must specify either -r / --repositories or -f /--repositories-file"
  usage
fi

function get_repo_id {
  # Get the ID of the repository
  repositoryId="$(gh api graphql -f query='{repository(owner:"'"${OWNER}"'",name:"'"${REPO}"'"){id}}' -q .data.repository.id)"
}

function get_rule_id {
  # Get the ID of the branch protection rule that matches "$PATTERN"
  branchProtectionRuleId="$(get_rules | jq -r '.data.repository.branchProtectionRules.nodes[] | select(.pattern == "'"$PATTERN"'") | .id')"
}

function get_rules {
  get_repo_id

  gh api graphql \
    -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=showBranchProtection \
    -F owner="$OWNER" -F repo="$REPO" \
    -F repositoryId="$repositoryId"
}

function backup_rules {
  get_rules | jq -r '.data.repository.branchProtectionRules.nodes[]' >"branch-protection-rules-${REPO}-$(date +%Y%m%d).json"
}

function create_rule {
  gh api graphql -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=addBranchProtection \
    -f PATTERN="$PATTERN" \
    -f repositoryId="$repositoryId"
  # TODO: add contexts, see note at top of file
}

function delete_rule {
  if [[ -z "$branchProtectionRuleId" ]]; then
    echo "No existing branch protection rule found matching '$PATTERN'"
  fi

  confirm "Are you sure you want to delete the branch protection rule with ID '${branchProtectionRuleId}', matching '$PATTERN' on repository '$REPO'?" "echo confirmed..."

  gh api graphql -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=deleteBranchProtection \
    -f ruleId="$branchProtectionRuleId" \
    -f repositoryId="$repositoryId"
}

function backup_rules {
  BACKUP_FILE="branch-protection-rules-${REPO}-$(date +%Y%m%d).json"
  # Check if the backup file already exists, if it does prompt the user to overwrite it, otherwise create it
  if [[ -f "$BACKUP_FILE" ]]; then
    ls -l "$BACKUP_FILE"
    confirm "Backup file already exists, overwrite?" "rm -f $BACKUP_FILE"
  fi

  get_rules | jq -r '.data.repository.branchProtectionRules.nodes[]' >"$BACKUP_FILE"
  echo "Created backup file: ${BACKUP_FILE}"
}

#
function confirm {
  if [[ "$FORCE" == true ]]; then
    $2
  fi

  echo "$1 [y/N]"
  read -r confirm
  if [[ "$confirm" == "y" ]]; then
    $2
  else
    echo "Aborting..."
    exit 1
  fi
}

function run_action {
  case "$ACTION" in
  backup)
    backup_rules
    ;;
  create)
    backup_rules
    get_rule_id
    create_rule
    ;;
  delete)
    backup_rules
    get_rule_id
    delete_rule
    ;;
  *)
    echo "Unknown action '$ACTION'"
    usage
    ;;
  esac
}

### Main ###
if $FORCE; then
  echo "Running with FORCE = true, will not prompt for confirmation!"
fi

for REPO in "${REPOS_ARRAY[@]}"; do
  echo "REPO: ${REPO}"

  # Get the repo ID
  get_repo_id

  # Run the desired action
  run_action

done
