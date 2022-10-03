
tell application "Microsoft Teams"
	reopen
	activate
end tell

tell application "System Events" to keystroke "m" using {shift down, command down}

# Requires enabling System Events control for the tool that runs this script
# (Automator / Script Editor / Shortcuts / BetterTouchTool etc...)
# under System Preferences > Security & Privacy > Privacy > Automation
