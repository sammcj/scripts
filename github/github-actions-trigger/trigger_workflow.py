#!/usr/bin/env python3
#
# Used to trigger a workflow in Github Actions
#
#       - name: Send dispatch to deploy workflow
# run: |
#   export PRIVATE_KEY='${{ secrets.MY_GITHUB_APP_PRIVATE_KEY }}'
#   python3 scripts/trigger_workflow.py
#

import time
import requests
import jwt
import json
import sys
import os
from cryptography.hazmat.backends import default_backend

REPO_NAME = "my-repo-name"
WORKFLOW_TEMPLATE_NAME = "deploy.yml"
ORG_NAME = "myOrg"
GITHUB_APP_ID = "12345"

try:
    env_value = os.getenv('PRIVATE_KEY')
    private_key = default_backend().load_pem_private_key(env_value.encode(), None)

    app_jwt = jwt.encode({'iss': GITHUB_APP_ID, 'iat': int(
        time.time()) - 60, 'exp': int(time.time()) + 600}, private_key, algorithm='RS256')

    installations = json.loads(requests.get('https://api.github.com/app/installations', headers={
        'Authorization': 'Bearer {}'.format(app_jwt), 'Accept': 'application/vnd.github.machine-man-preview+json'}).content.decode())
    installation_id = list(
        filter(lambda x: x['account']['login'] == ORG_NAME, installations))[0]['id']

    access_token = json.loads(requests.post('https://api.github.com/app/installations/{}/access_tokens'.format(installation_id), headers={
        'Authorization': 'Bearer {}'.format(app_jwt), 'Accept': 'application/vnd.github.machine-man-preview+json'}).content.decode())['token']

    response = requests.post('https://api.github.com/repos/{}/{}/actions/workflows/{}/dispatches'.format(ORG_NAME, REPO_NAME, WORKFLOW_TEMPLATE_NAME),
                             headers={'Authorization': 'Bearer {}'.format(access_token), 'Accept': 'application/vnd.github.v3+json'}, json={'ref': 'main'})

    response.raise_for_status()
except Exception as e:
    print(e)
