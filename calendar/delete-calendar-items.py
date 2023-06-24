#/usr/bin/env python3
#
# This script will list and remove all events from a local calendar file that match a given string.
# Author: Sam McLeod

import re

def read_calendar_file(file_path):
    with open(file_path, 'r') as file:
        return file.read()

def remove_events_matching_string(calendar_data, search_string):
    pattern = re.compile(search_string, re.IGNORECASE)
    events = re.findall('BEGIN:VEVENT.*?END:VEVENT', calendar_data, re.DOTALL)
    matched_events = []
    updated_calendar_data = calendar_data

    for event in events:
        if re.search(pattern, event):
            matched_events.append(event)
            updated_calendar_data = updated_calendar_data.replace(event, '')

    return matched_events, updated_calendar_data

def main():
    file_path = input("Enter the path to the exported calendar file: ")
    search_string = input("Enter the string to search for in the events: ")

    calendar_data = read_calendar_file(file_path)
    matched_events, updated_calendar_data = remove_events_matching_string(calendar_data, search_string)

    print("\nMatched Events:")
    for event in matched_events:
        print(event)

    confirmation = input("\nDo you want to remove the matched events? (yes/no): ")
    if confirmation.lower() == 'yes':
        with open(file_path, 'w') as file:
            file.write(updated_calendar_data)
        print("Matched events removed successfully.")
    else:
        print("No events were removed.")

if __name__ == '__main__':
    main()
