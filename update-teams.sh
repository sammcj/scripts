#!/usr/bin/env bash
set -eoux pipefail
URL="raw.githubusercontent.com/ItzLevvie/MicrosoftTeams-msinternal/master/defconfig"

# Cleanup old installers
rm -f ~/Downloads/MicrosoftTeamsArm64Beta.pkg

# Curl the URL and get the only the first line containing the string "osx-arm64"
curl -L -s $URL | grep "osx-arm64" | head -n 1 | grep -o 'https://staticsint.teams.cdn.office.net.*' | xargs curl -L -s -o ~/Downloads/MicrosoftTeamsArm64Beta.pkg

# Install the MicrosoftTeamsArm64Beta.pkg (optional: add this to sudoers no password if you REALLY trust the downloaded file)
sudo /usr/sbin/installer -pkg ~/Downloads/MicrosoftTeamsArm64Beta.pkg -target /Applications/

open /Applications/Microsoft\ Teams.app

sudo rm -rf /Library/Audio/Plug-Ins/HAL/MSTeamsAudioDevice.driver
