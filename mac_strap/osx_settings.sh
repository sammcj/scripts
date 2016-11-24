#!/bin/bash
# Designed for 10.11

### General OSX Settings

# Reduce Transparency
defaults write com.apple.universalaccess reduceTransparency -bool true

# Disable local timemachine backups
sudo tmutil disablelocal

# Disable sudden motion sensor
sudo pmset -a sms 0

# Enable AirDrop over Ethernet and on Unsupported Macs
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Set Software Update Check Interval to daily
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

### Finder

# Show Full Path in Finder Title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Unhide User Library Folder
chflags nohidden ~/Library

# Disable smooth scrolling
defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true && \
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Save to disk by default, rather than iCloud
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Set current folder as default search scope
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable Creation of Metadata Files on Network and USB Volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true



### App settings

## Textedit
# Use Plain Text Mode as Default
defaults write com.apple.TextEdit RichText -int 0

## Mail
# Show Attachments as Icons
defaults write com.apple.mail DisableInlineAttachmentViewing -bool yes


## Skitch
# Export Compact SVGs
defaults write com.bohemiancoding.sketch3 exportCompactSVG -bool yes
