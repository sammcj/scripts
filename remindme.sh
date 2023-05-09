#!/usr/bin/env bash
# remindme - A simple reminder script for zsh/bash

# To use this script, add the following function to your .zshrc:
#
# # Add the path to the remindme.sh file
# REMINDME_PATH="path/to/remindme.sh"
#
# # Configure directories to check for reminders
# CHECK_REMINDER_DIRECTORIES=("~/git" "~/Documents")
#
# # Function to check if the current directory is in the list of directories to check
# should_check_reminders() {
#     local dir
#     for dir in "${CHECK_REMINDER_DIRECTORIES[@]}"; do
#         if [[ "$(realpath "$PWD")" == "$(realpath "$dir")" ]]; then
#             return 0
#         fi
#     done
#     return 1
# }

# # Function to check for reminders related to the current directory
# check_reminders_on_chdir() {
#     if should_check_reminders; then
#         local reminders
#         reminders=$(source "$REMINDME_PATH" -l | grep "$PWD" | sed 's/[^=]*= //')
#         if [ -n "$reminders" ]; then
#             echo "Reminders for this directory:"
#             echo "$reminders"
#             echo "Use 'remindme -d <reminder_id>' to mark a reminder as completed."
#         fi
#     fi
# }

# # Call the check_reminders_on_chdir function whenever you change directories
# autoload -U add-zsh-hook
# add-zsh-hook chpwd check_reminders_on_chdir

# # Define the reminder_me function for convenience
# remind_me() {
#     source "$REMINDME_PATH" "$@"
# }

# Ensure required tools are installed
if ! command -v fzf &>/dev/null; then
  echo "Fzf is not installed. Please install fzf for ReminderMe to work."
  exit 0 # because exit 1 would kill the shell
fi

# Define the ReminderMe configuration directory and file
REMINDME_DIR="$HOME/.remindme"
REMINDME_CONFIG="$REMINDME_DIR/config.toml"

# Ensure the ReminderMe configuration directory exists
if [ ! -d "$REMINDME_DIR" ]; then
  mkdir -p "$REMINDME_DIR"
fi

# Ensure the ReminderMe configuration file exists
if [ ! -f "$REMINDME_CONFIG" ]; then
  touch "$REMINDME_CONFIG"
fi

# Generate a random reminder ID
generate_reminder_id() {
  local date
  date="$(date +%Y-%m-%d)"
  local words=("cat" "dog" "lizard" "chicken" "horse" "goat" "snake" "fish")
  local first_word="${words[RANDOM % ${#words[@]}]}"
  local second_word="${words[RANDOM % ${#words[@]}]}"
  echo "${date}-${first_word}-${second_word}"
}

# Add a new reminder
add_reminder() {
  local reminder_id
  reminder_id=$(generate_reminder_id)
  echo "$reminder_id = \"$PWD: $1\"" >>"$REMINDME_CONFIG"
  echo "Reminder added with ID: $reminder_id"
}

# List all reminders
list_reminders() {
  cat "$REMINDME_CONFIG"
}

# Delete a reminder
delete_reminder() {
  local reminder_id="$1"
  if [ -z "$reminder_id" ]; then
    reminder_id=$(list_reminders | fzf | awk -F ' = ' '{print $1}')
  fi

  sed -i "/^$reminder_id/d" "$REMINDME_CONFIG"
  echo "Reminder with ID $reminder_id deleted."
}

# Show usage
usage() {
  echo "Usage:"
  echo "  remindme <reminder_text>     Add a new reminder"
  echo "  remindme -l                  List all reminders"
  echo "  remindme -d [reminder_id]    Delete reminder"
}

# Main function
remindme() {
  local action="$1"

  case "$action" in
  -l)
    list_reminders
    ;;
  -d)
    delete_reminder "$2"
    ;;
  *)
    if [ -z "$action" ]; then
      usage
    else
      add_reminder "$*"
    fi
    ;;
  esac
}

# Call the main function with the given arguments
remindme "$@"
