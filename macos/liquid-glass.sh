#!/usr/bin/env bash

ARG="$1"

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

usage() {
  echo "Usage: $0 [enable|disable]"
  echo "  enable - Enable LiquidGlass"
  echo "  disable - Disable LiquidGlass"
}

if [ "$ARG" != "enable" ] && [ "$ARG" != "disable" ]; then
  echo "Error: Invalid argument. Must specify either 'enable' or 'disable'"
  usage
  exit 1
fi

if [ "$ARG" = "disable" ]; then
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist EnhancedGlass -dict Enabled -bool false
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist SolariumCornerRadius -dict Enabled -bool false
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist inject_solarium_assets -dict Enabled -bool false
  defaults write /Library/Preferences/FeatureFlags/Domain/SwiftUI.plist Solarium -dict Enabled -bool false
else
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist EnhancedGlass -dict Enabled -bool true
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist SolariumCornerRadius -dict Enabled -bool true
  defaults write /Library/Preferences/FeatureFlags/Domain/IconServices.plist inject_solarium_assets -dict Enabled -bool true
  defaults write /Library/Preferences/FeatureFlags/Domain/SwiftUI.plist Solarium -dict Enabled -bool true
fi

echo "You need to restart your computer for the changes to take effect."
