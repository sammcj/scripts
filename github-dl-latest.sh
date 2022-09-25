#!/usr/bin/env bash

# Find the latest release from a Github repo and downloads it for your platform/arch.

# Usage: ./github-dl-latest.sh <owner>/<repo>
# Example: ./github-dl-latest.sh hashicorp/terraform

if [ -z "$1" ]; then
  echo "Usage: github-dl-latest <repo>"
  echo "Example: github-dl-latest docker/compose"
  echo "Example (with token): GH_TOKEN=123456 github-dl-latest docker/compose"
  return 1
fi

REPO="$1"

# Optionally add your Github username and a token to avoid API rate limiting
GITHUB_USER=""
GITHUB_PASS="${GITHUB_PASS:-$GITHUB_TOKEN}"

# If GITHUB_USER isn't empty, use it to authenticate
if [ -n "$GITHUB_USER" ]; then
  GITHUB_AUTH="-u ${GITHUB_USER}:${GITHUB_PASS}"
else
  GITHUB_AUTH=""
fi

case "$(uname -s)" in
Darwin)
  PLATFORM="darwin"
  ;;
Linux)
  PLATFORM="linux"
  ;;
*)
  echo "Unsupported platform: $(uname -s)"
  return 1
  ;;
esac

case "$(uname -m)" in
x86_64)
  ARCH="amd64"
  ;;
arm64)
  ARCH="[aarch64 | arm64]"
  ;;
*)
  echo "Unsupported architecture: $(uname -m)"
  return 1
  ;;
esac

# gh api "repos/$REPO/releases/latest"
URL=$(curl "$GITHUB_AUTH" --silent "https://api.github.com/repos/${REPO}/releases/latest" | jq -r ".assets[] | select(.name | match(\"${PLATFORM}-${ARCH}\") and (contains(\"sha256\") | not)) | .browser_download_url")
FILE=$(basename "$URL")

echo "Downloading ${FILE} from ${URL}"
curl -L "$URL" -o "$FILE"
