import subprocess
import time

# This script moves events from one calendar to another based on a search string.

def select_calendar(prompt):
    script = """
    tell application "Calendar"
        set calendarsList to {}
        set calendarNames to {}
        repeat with calendarItem in calendarsList
            set end of calendarNames to name of calendarItem
        end repeat
    end tell
    return calendarNames
    """

    script = script.format("calendars", "calendarsList")

    # Execute the AppleScript code to fetch the calendar names
    calendar_names = subprocess.check_output(['osascript', '-e', script]).decode().strip().split(', ')
    print(prompt)
    for i, name in enumerate(calendar_names):
        print("{}. {}".format(i+1, name))

    while True:
        try:
            selection = int(input("Enter the number of the calendar: "))
            if 1 <= selection <= len(calendar_names):
                return calendar_names[selection - 1]
            else:
                print("Invalid selection. Please try again.")
        except ValueError:
            print("Invalid input. Please enter a number.")


def move_events_matching_string(source_calendar, target_calendar, search_string):
    script = """
    tell application "Calendar"
        set sourceCal to calendar "{}"
        set targetCal to calendar "{}"
        set matchingEvents to every event of sourceCal
        set matchingEventTitles to {{}}
        repeat with eventToMove in matchingEvents
            if (summary of eventToMove contains "{}" or description of eventToMove contains "{}" or url of eventToMove contains "{}") then
                set end of matchingEventTitles to summary of eventToMove
            end if
        end repeat
        matchingEventTitles
    end tell
    """

    # Escape special characters in the search string
    escaped_search_string = search_string.replace('"', r'\"')

    # Generate AppleScript code to find matching events and get their titles
    script = script.format(source_calendar, target_calendar, escaped_search_string, escaped_search_string, escaped_search_string, '{}')

    # Execute the AppleScript code to fetch matching event titles
    try:
        matching_event_titles = subprocess.check_output(['osascript', '-e', script]).decode().strip().split(', ')
    except subprocess.CalledProcessError:
        matching_event_titles = []

    if len(matching_event_titles) > 0:
        print("The following events match the search criteria:")
        for i, title in enumerate(matching_event_titles):
            print("{}. {}".format(i+1, title))

        confirmation = input("Do you want to proceed? (y/n): ")
        if confirmation.lower() == 'y':
            move_script = """
            tell application "Calendar"
                set sourceCal to calendar "{}"
                set targetCal to calendar "{}"
                set matchingEvents to every event of sourceCal
                repeat with eventToMove in matchingEvents
                    if (summary of eventToMove contains "{}" or description of eventToMove contains "{}" or url of eventToMove contains "{}") then
                        move eventToMove to targetCal
                    end if
                    -- Delay to avoid AppleEvent timed out error
                    delay 0.1
                end repeat
            end tell
            """
            move_script = move_script.format(source_calendar, target_calendar, escaped_search_string, escaped_search_string, escaped_search_string)

            # Execute the AppleScript code to move events
            subprocess.run(['osascript', '-e', move_script])

            print("Events moved successfully.")
        else:
            print("Operation canceled.")
    else:
        print("No events matching the search criteria found.")


# Usage
source_calendar = select_calendar("Select the source calendar:")
target_calendar = select_calendar("Select the target calendar:")
search_string = input("Enter the search string: ")

move_events_matching_string(source_calendar, target_calendar, search_string)
