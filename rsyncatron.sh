#!/usr/bin/env bash
#
# This script takes a source and destination suitable for rsync, checks which
# files are out of date or missing at the destination, and prompts the user to
# interactively select which files they want to update at the destination using
# rsync and fzf. The user's selections are written to a JSON5/JSONC file. If a
# config file exists in the current working directory, the user is prompted if
# they want to use the existing selections configured instead.
#
# Inputs: Source and destination suitable for rsync (e.g., user@computer:/mnt/directory /tmp/files)
# Outputs: An updated destination directory and a log file in the current working directory
# Requires: fzf, fd, rsync, and jq to be installed on the system

set -o errexit
set -o nounset
set -o pipefail

set -x

# Replace the placeholder with your actual username and hostname (or IP address) of your remote server
USER_AT_COMPUTER="root@rockpi"

# Check if required tools are installed
command -v fzf >/dev/null 2>&1 || {
  echo >&2 "fzf is required but not installed. Exiting."
  exit 1
}
command -v rsync >/dev/null 2>&1 || {
  echo >&2 "rsync is required but not installed. Exiting."
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo >&2 "jq is required but not installed. Exiting."
  exit 1
}
command -v fd >/dev/null 2>&1 || {
  echo >&2 "fd is required but not installed. Exiting."
  exit 1
}

# Function to print error messages
function error() {
  echo "Error: $1" >&2
  exit 1
}

# Check input arguments
if [ "$#" -ne 2 ]; then
  error "Invalid number of arguments. Usage: $0 <source> <destination>"
fi

SOURCE="$1"
DESTINATION="$2"
LOGFILE="$(pwd)/rsync_fzf.log"
CONFIGFILE="$(pwd)/rsync_fzf_config.json5"

# Check if a config file exists and prompt the user if they want to use it
if [ -f "$CONFIGFILE" ]; then
  read -p "A config file was found. Do you want to use the existing selections? (y/n) " USE_CONFIG
  if [ "$USE_CONFIG" == "y" ]; then
    SELECTIONS=$(cat "$CONFIGFILE")
  fi
else
  # Create a temporary script file to store the dir_tree function
  TEMP_SCRIPT=$(mktemp)

  # Write the dir_tree function to the temporary script file
  cat >"$TEMP_SCRIPT" <<EOL
cat >"$TEMP_SCRIPT" <<EOL
#!/usr/bin/env bash
user_at_computer="\$1"
SOURCE="\$2"
path="\$3"
trimmed_source=\$(echo "\$SOURCE" | sed 's:/*$::')  # Add this line to trim trailing slashes

if [ -z "\$path" ]; then
  # List top-level directories, including hidden ones
  ssh \$user_at_computer "find \$trimmed_source -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
else
  # Check if the given path is a directory
  is_directory=\$(ssh \$user_at_computer "if [ -d \"\$trimmed_source/\$path\" ]; then echo 'yes'; else echo 'no'; fi")

  if [ "\$is_directory" == "yes" ]; then
    # List files and directories in the selected path, including hidden ones
    ssh \$user_at_computer "find \$trimmed_source/\$path -mindepth 1 -maxdepth 1 -printf '%P\n'
  else
    # If the path is not a directory, do not list its content
    echo ""
  fi
fi
EOL

  # Make the temporary script executable
  chmod +x "$TEMP_SCRIPT"

  # Prompt user to interactively select files using fzf with directory browsing
  SELECTIONS=$(fzf --ansi --multi --prompt="Select files to update: " --preview="bash -c '$TEMP_SCRIPT \"$USER_AT_COMPUTER\" \"$SOURCE\" {}'" --preview-window=right:50% --bind "ctrl-d:preview-page-down" --bind "ctrl-u:preview-page-up" --bind "enter:execute($TEMP_SCRIPT \"$USER_AT_COMPUTER\" \"$SOURCE\" {} | fzf --ansi --multi --header='Enter: select, Esc: back' --preview='bash -c \"$TEMP_SCRIPT \\\"$USER_AT_COMPUTER\\\" \\\"$SOURCE\\\" {}/{}\"' --preview-window=right:50% --bind 'enter:execute(echo {}/{} | tr -d \"''\")')")

  # Remove any empty lines from the selections
  SELECTIONS=$(echo "$SELECTIONS" | sed '/^$/d')

  # Clean up the temporary script file
  rm -f "$TEMP_SCRIPT"

  # Save user selections to the config file
  echo "$SELECTIONS" | jq --slurp --raw-input --raw-output 'split("\n")[:-1]' >"$CONFIGFILE"
fi

# Perform a dry run first
echo "Performing a dry run..." | tee -a "$LOGFILE"
rsync -n -av --files-from=<(echo "$SELECTIONS") "$SOURCE" "$DESTINATION" | tee -a "$LOGFILE"

# Prompt the user to continue, exit, or change the selections
while true; do
  read -p "Do you want to continue with the updates (c), exit (e), or change the selections (s)? " CHOICE
  case "$CHOICE" in
  c)
    break
    ;;
  e)
    echo "Exiting without updating files." | tee -a "$LOGFILE"
    exit 0
    ;;
  s)
    # List the directories in the source path
    DIRS=$(ssh user@computer "find $SOURCE -type d")

    # Prompt user to interactively select files using fzf with tree preview
    SELECTIONS=$(echo "$DIRS" | fzf --ansi --multi --prompt="Select files to update: " --preview='ssh '$USER_AT_COMPUTER' "tree -C -f -L 1 --noreport {} | tail -n +2"' --preview-window=right:50% --bind "ctrl-d:preview-page-down" --bind "ctrl-u:preview-page-up")

    # Save user selections to the config file
    echo "$SELECTIONS" | jq --slurp --raw-input --raw-output 'split("\n")[:-1]' >"$CONFIGFILE"

    # Perform a dry run again
    echo "Performing a dry run with new selections..." | tee -a "$LOGFILE"
    rsync -n -av --files-from=<(echo "$SELECTIONS") "$SOURCE" "$DESTINATION" | tee -a "$LOGFILE"
    ;;
  *)
    echo "Invalid input. Please enter 'c', 'e' or 's'"
    ;;
  esac
done

# Update the selected files at the destination using rsync
echo "Updating selected files..." | tee -a "$LOGFILE"
rsync -av --files-from=<(echo "$SELECTIONS") "$SOURCE" "$DESTINATION" | tee -a "$LOGFILE"
echo "Update complete." | tee -a "$LOGFILE"
