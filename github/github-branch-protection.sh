#!/usr/bin/env bash

set -ueo pipefail

# https://cli.github.com/manual/gh_api_graphql
# https://docs.github.com/en/graphql/reference/objects#branchprotectionrule

# unset GITHUB_TOKEN as we're using gh auth
unset GITHUB_TOKEN

OWNER=myuser
branchPattern="*protected*"

# Create an array of repositories from a file with a list of repos
readarray -t REPOS <repos.txt

# TODO:
# - Contexts (see create_rule below)

function get_rules {
  gh api graphql \
    -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=showBranchProtection \
    -F owner=$OWNER -F repo=$REPO \
    -F repositoryId=$repositoryId
}

function backup_rules {
  get_rules | jq -r '.data.repository.branchProtectionRules.nodes[]' >"branch-protection-rules-${REPO}-$(date +%Y%m%d).json"
}

function create_rule {
  gh api graphql -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=addBranchProtection \
    -f branchPattern=$branchPattern \
    -f repositoryId=$repositoryId

  # Add contexts manually via input due to this bug - https://github.com/cli/cli/issues/1484
  # jq -n '{"required_status_checks":{"strict":true,"contexts":["lint-pr / lint, coverage","lint-and-test (dev, 750609712134)","build-shared (shared, 350227333798)"]}}' | gh api -X PUT repos/ --input - "${OWNER}/${REPO}/branches/${branchPattern}/protection"
}

function delete_rule {
  branchProtectionRuleId="$(get_rules | jq -r '.data.repository.branchProtectionRules.nodes[].id')" #TODO: | match("$PATTERN";"i")
  gh api graphql -f query="$(cat github-branch-protection.graphql)" \
    -f operationName=deleteBranchProtection \
    -f ruleId=$branchProtectionRuleId \
    -f repositoryId=$repositoryId
}

# loop over $REPOS and get_rules
for REPO in "${REPOS[@]}"; do

  echo "REPO: ${REPO}"

  repositoryId="$(gh api graphql -f query='{repository(owner:"'${OWNER}'",name:"'${REPO}'"){id}}' -q .data.repository.id)"

  # backup first
  get_rules | jq -r '.data.repository.branchProtectionRules.nodes[]' >"branch-protection-rules-${REPO}-$(date +%Y%m%d).json"

  create_rule
done
