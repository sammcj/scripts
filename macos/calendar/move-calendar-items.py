#/usr/bin/env python3
#
# This script moves calendar events from one calendar to another based on a search string.
# Author: Sam McLeod
#
# There is a bug where it times out trying to connect to the Calendar app if there are too many events to move.

import subprocess
def select_calendar(prompt, default_calendar=None, match_string=None):
    script = """
    tell application "Calendar"
        set matchingCalendars to {}
        set calendarNames to {{}}
        repeat with calendarItem in matchingCalendars
            set end of calendarNames to name of calendarItem
        end repeat
    end tell
    return calendarNames
    """

    if default_calendar:
        script = script.format("calendars where name contains '{}'".format(default_calendar), "matchingCalendars")
    elif match_string:
        script = script.format("calendars where name contains '{}'".format(match_string), "matchingCalendars")
    else:
        script = script.format("calendars", "matchingCalendars")

    # Execute the AppleScript code to fetch the calendar names
    try:
        calendar_names = subprocess.check_output(['osascript', '-e', script]).decode().strip().split(', ')
    except subprocess.CalledProcessError:
        calendar_names = []

    if not calendar_names:
        if default_calendar:
            print("No matching calendars found. Defaulting to '{}'.".format(default_calendar))
            return default_calendar
        else:
            print("No matching calendars found.")
            return None

    print(prompt)
    for i, name in enumerate(calendar_names):
        print("{}. {}".format(i+1, name))

    while True:
        try:
            selection = input("Enter the number of the calendar: ")
            if not selection:
                selection = default_calendar
                break
            selection = int(selection)
            if 1 <= selection <= len(calendar_names):
                return calendar_names[selection - 1]
            else:
                print("Invalid selection. Please try again.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    if not selection:
        print("Invalid input. Defaulting to '{}'.".format(default_calendar))
        return default_calendar

def move_events_matching_string(source_calendar, target_calendar, search_string):
    script = """
    tell application "Calendar"
        set sourceCal to calendar "{}"
        set targetCal to calendar "{}"
        set matchingEvents to events of sourceCal whose (start date > current date) and (summary contains "{}" or description contains "{}" or url contains "{}")
        set matchingEventTitles to {{}}
        repeat with eventToMove in matchingEvents
            set end of matchingEventTitles to summary of eventToMove
        end repeat
        matchingEventTitles
    end tell
    """

    # Escape special characters in the search string
    escaped_search_string = search_string.replace('"', r'\"')

    # Generate AppleScript code to find matching events and get their titles
    script = script.format(source_calendar, target_calendar, escaped_search_string, escaped_search_string, escaped_search_string)

    batch_size = 10  # Number of events to process in each batch

    # Execute the AppleScript code to fetch matching event titles
    try:
        matching_event_titles = subprocess.check_output(['osascript', '-e', script], timeout=10).decode().strip().split(', ')
    except subprocess.TimeoutExpired:
        matching_event_titles = []
        print("AppleEvent timed out while retrieving events.")
    except subprocess.CalledProcessError:
        matching_event_titles = []
        print("An error occurred while retrieving events.")

    if not matching_event_titles:
        print("No events matching the search criteria found.")
        return

    print("Total events found: {}".format(len(matching_event_titles)))

    total_events = 0
    batch_index = 0

    while batch_index * batch_size < len(matching_event_titles):
        batch_events = matching_event_titles[batch_index * batch_size: (batch_index + 1) * batch_size]

        print("Batch {}: Processing {} events".format(batch_index + 1, len(batch_events)))

        move_script = """
        tell application "Calendar"
            set sourceCal to calendar "{}"
            set targetCal to calendar "{}"
            set matchingEvents to events of sourceCal whose summary is in {{{}}}
            repeat with eventToMove in matchingEvents
                move eventToMove to targetCal
                -- Delay to avoid AppleEvent timed out error
                delay 0.1
            end repeat
        end tell
        """
        move_script = move_script.format(source_calendar, target_calendar, ', '.join(['"{}"'.format(event) for event in batch_events]))

        # Execute the AppleScript code to move events
        try:
            subprocess.run(['osascript', '-e', move_script], timeout=10)
            total_events += len(batch_events)
            print("Batch {}: {} events moved successfully.".format(batch_index + 1, len(batch_events)))
        except subprocess.TimeoutExpired:
            print("Batch {}: AppleEvent timed out while moving events.".format(batch_index + 1))
        except subprocess.CalledProcessError:
            print("Batch {}: An error occurred while moving events.".format(batch_index + 1))

        batch_index += 1

    print("Total events moved: {}".format(total_events))

# Usage
default_source_calendar = select_calendar("Select the source calendar (default: Calendars with email addresses):", match_string="fastmail")
default_target_calendar = select_calendar("Select the target calendar (default: Music Releases):", match_string="Music Releases")
source_calendar = select_calendar("Select the source calendar:", default_calendar=default_source_calendar)
target_calendar = select_calendar("Select the target calendar:", default_calendar=default_target_calendar)
search_string = input("Enter the search string (default: music.apple.com): ") or "music.apple.com"

if source_calendar and target_calendar:
    move_events_matching_string(source_calendar, target_calendar, search_string)
