# github-branch-protection.sh

Author: Sam McLeod @sammcj

This script is used to backup, create, or delete branch protection rules on Github.
It uses the Github GraphQL API to query and manipulate branch protection rules.

The required graphql schema and specific protection rules is defined in the file [github-branch-protection.graphql](github-branch-protection.graphql).

Defaults:

```graphql
      allowsDeletions: false
      allowsForcePushes: false
      dismissesStaleReviews: true
      isAdminEnforced: false
      pattern: $branchPattern
      repositoryId: $repositoryId
      requiresApprovingReviews: true
      requiredApprovingReviewCount: 1
      requiresCodeOwnerReviews: true
      requiredStatusCheckContexts: $requiredStatusChecks
      requiresStatusChecks: true
      restrictsReviewDismissals: false
```

## Usage

```bash
./github-branch-protection.sh --action [backup|create|delete]
                              --pattern [branch pattern to match]
                              --owner [owner of the repositories]
                              (
                                --repositories 'repo-1 repo-2'
                              or
                                --repositories-file [file containing repositories on each line]
                              )
                              --FORCE [true|false]
```

Example:

```bash
# Providing a list of repositories
./github-branch-protection.sh --action backup --pattern 'main' --owner 'myOrg' --repositories 'repo-1 repo-2'
# Or with a file
./github-branch-protection.sh --action backup --pattern 'main' --owner 'myOrg' --repositories-file repositories.txt
```

## TODO

- Parametrise protection settings out of the graphql file.

- Add ability to set Required Status Check Contexts.

This is not possible the the gh cli tool due to this Github bug - <https://github.com/cli/cli/issues/1484>

You can add them manually via the Github UI or via a CURL request along the lines of:

```bash
jq -n '{"required_status_checks":{"strict":true,"contexts":["lint-pr / lint, coverage","lint-and-test (dev, 1234567890)","build-shared (test, 2345678901)"]}}' \
  | gh api -X PUT repos/ --input - "${OWNER}/${REPO}/branches/${branchPattern}/protection"
```

## Links

- <https://cli.github.com/manual/gh_api_graphql>
- <https://docs.github.com/en/graphql/reference/objects#branchprotectionrule>
