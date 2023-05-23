#!/usr/bin/env bash

# remindme - A simple reminder script for zsh/bash
# See the end of the file for .zshrc examples

# Ensure required tools are installed
if ! command -v fzf &>/dev/null; then
  echo "Fzf is not installed. Please install fzf for remindme to work."
  exit 0
fi

# Define the remindme configuration directory and file
REMINDME_DIR="$HOME/.remindme"
REMINDME_CONFIG="$REMINDME_DIR/config.toml"
COMMAND_NAME="remind"

# Ensure the remindme configuration directory exists
if [ ! -d "$REMINDME_DIR" ]; then
  mkdir -p "$REMINDME_DIR"
fi

# Ensure the remindme configuration file exists
if [ ! -f "$REMINDME_CONFIG" ]; then
  touch "$REMINDME_CONFIG"
fi

# Generate a random reminder ID
generate_reminder_id() {
  local date
  date="$(date +%Y-%m-%d)"
  local words=("cat" "turkey" "dog" "lizard" "chicken" "horse" "goat" "snake" "fish" "burger" "potato")
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
  echo "  ${COMMAND_NAME} <reminder_text>     Add a new reminder"
  echo "  ${COMMAND_NAME} -l                  List all reminders"
  echo "  ${COMMAND_NAME} -d [reminder_id]    Delete reminder"
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

#######

### remindme ###
# REMINDME_PATH="${HOME}/git/scripts/remindme.sh"
# COMMAND_NAME="remind"
# #
# # Configure directories to check for reminders
# CHECK_REMINDER_DIRECTORIES=("${HOME}/git" "${HOME}/Documents")
# #
# # Function to check if the current directory is in the list of directories to check
# should_check_reminders() {
#   local dir
#   for dir in "${CHECK_REMINDER_DIRECTORIES[@]}"; do
#     if [[ "${PWD/#$HOME/~}" == "$dir" ]]; then
#       return 0
#     fi
#   done
#   return 1
# }

# # Function to check for reminders related to the current directory
# check_reminders_on_chdir() {
#   if should_check_reminders; then
#     local reminders
#     reminders=$(source "$REMINDME_PATH" -l | while IFS= read -r line; do
#       if [[ "$line" == *"$PWD"* ]]; then
#         echo "${line#*= }"
#       fi
#     done)
#     if [ -n "$reminders" ]; then
#       echo "Reminders for this directory:"
#       echo "$reminders"
#       echo "Use '''${COMMAND_NAME} -d <reminder_id>''' to mark a reminder as completed."
#     fi
#   fi
# }

# # Call the check_reminders_on_chdir function whenever you change directories
# autoload -U add-zsh-hook
# add-zsh-hook chpwd check_reminders_on_chdir

# # Define the reminder_me function for convenience
# remind() {
#   source "$REMINDME_PATH" "$@"
# }
