#!/usr/bin/env bash
set -eoux pipefail
URL="raw.githubusercontent.com/ItzLevvie/MicrosoftTeams-msinternal/master/defconfig"
PACKAGE_NAME="MicrosoftTeamsArm64Beta.pkg"

# Detect if teams is already installed with homebrew (microsoft-teams cask), if is, skip to removing the audio driver and exit 0
if [[ -n "$(brew list --cask | grep microsoft-teams)" ]]; then
  echo "Microsoft Teams is already installed with homebrew, skipping to removing the audio driver and exiting"
  sudo rm -rf /Library/Audio/Plug-Ins/HAL/MSTeamsAudioDevice.driver
  exit 0
fi

# Backup existing installer and cleanup older versions
if [ -f ~/Downloads/$PACKAGE_NAME ]; then
  rm -f ~/Downloads/MicrosoftTeamsArm64Beta-old.pkg
  mv ~/Downloads/$PACKAGE_NAME ~/Downloads/MicrosoftTeamsArm64Beta-old.pkg
fi

# Curl the URL and get the only the first line containing the string "osx-arm64"
curl -L -s $URL | grep "osx-arm64" | head -n 1 | grep -o 'https://staticsint.teams.cdn.office.net.*' | xargs curl -L -s -o ~/Downloads/$PACKAGE_NAME

# Install the $PACKAGE_NAME (optional: add this to sudoers no password if you REALLY trust the downloaded file)
sudo /usr/sbin/installer -pkg ~/Downloads/$PACKAGE_NAME -target /Applications/

open /Applications/Microsoft\ Teams.app
