-- Gets the first MS Teams window that isn't the main window and toggles mute.
-- Requires enabling System Events control for the tool that runs this script (Automator / Script Editor / Shortcuts / BetterTouchTool etc...)
-- under System Preferences > Security & Privacy > Privacy > Automation

tell application "Microsoft Teams"
	reopen
	activate
	
	tell application "System Events"
		-- Get the frontmost app's *process* object.
		set frontAppProcess to first application process whose frontmost is true
	end tell
	
	tell frontAppProcess
		-- Get the first window that isn't the main window.
		set window_name to name of front window
	end tell
	
	tell window window_name
		activate
		-- Toggle mute.
		tell application "System Events"
			keystroke "m" using {shift down, command down}
		end tell
	end tell
end tell

