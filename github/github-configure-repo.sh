#!/usr/bin/env bash

owner="myorg"
name="if-test-repo-samm"
branch="main"
required_approving_review_count=1
require_code_owner_reviews=false
dismiss_stale_reviews=true
enforce_admins=true
required_linear_history=true
allow_force_pushes=false
allow_deletions=false
required_conversation_resolution=true
block_creations=false
required_status_checks="'lint-pr/lint', 'lint-actions-workflows/lint'"

curl \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    https://api.github.com/repos/$owner/$name/branches/$branch/protection \
    -d "{'enforce_admins':$enforce_admins,'required_pull_request_reviews':{'dismiss_stale_reviews':$dismiss_stale_reviews,'require_code_owner_reviews':$require_code_owner_reviews,'required_approving_review_count':$required_approving_review_count},'required_linear_history':$required_linear_history,'allow_force_pushes':$allow_force_pushes,'allow_deletions':$allow_deletions,'block_creations':$block_creations,'required_conversation_resolution':$required_conversation_resolution, 'required_status_checks':{'strict':true,'contexts':[$required_status_checks]} }"
