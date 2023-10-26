#!/usr/bin/env bash

# This script is used to launch vorta on macOS.
VORTA_LUNCHD="${HOME}/Library/LaunchAgents/com.vorta.plist"
VORTA="/Users/samm/.pyenv/shims/vorta"
PYENV_ROOT="/Users/samm/.pyenv"

# Check if vorta and borg are installed via pip, if not, install them.
if ! command -v vorta &>/dev/null; then
  echo "vorta could not be found, installing..."
  pip3 install vorta
fi

if ! command -v borg &>/dev/null; then
  echo "borg could not be found, installing..."
  pip3 install borgbackup
fi

# Check if there are updated versions of vorta and borg, if so, update them.
if pip3 list --outdated | grep -q "vorta"; then
  echo "vorta is outdated, updating..."
  pip3 install --upgrade vorta
fi

if pip3 list --outdated | grep -q "borgbackup"; then
  echo "borg is outdated, updating..."
  pip3 install --upgrade borgbackup
fi

# Add the borg binary to PATH
BORG_PATH=$(which borg)
export PATH=$PATH:$BORG_PATH

# Add vorat binary to PATH
export PATH=$VORTA:$PATH

function addLunchDJob() {
  # Inline launchd plist
  cat <<EOF >"$VORTA_LUNCHD"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$PATH</string>
		<key>PYENV_ROOT</key>
		<string>$PYENV_ROOT</string>
	</dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>vorta.job</string>
	<key>Program</key>
	<string>$VORTA</string>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>
EOF

  # Load the launchd plist
  launchctl load "$VORTA_LUNCHD"
}

# Check that the launchd plist is installed, if not, install it.
if [ ! -f "$VORTA_LUNCHD" ]; then
  echo "vorta launchd plist not found, installing..."
  addLunchDJob
fi
