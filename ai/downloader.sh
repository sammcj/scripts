#!/usr/bin/env bash

# Associative array to store base directories for each destination type
declare -A BASE_DIRECTORIES
BASE_DIRECTORIES=(["lora"]="/opt/downloads/loras/" ["textgen"]="/home/example/downloads/")

# Function to prompt user for destination type
select_destination() {
  echo "Available destination types:"
  for dest in "${!BASE_DIRECTORIES[@]}"; do
    echo "$dest"
  done

  read -p "Select a destination type: " choice
  if [ -n "${BASE_DIRECTORIES[$choice]}" ]; then
    SELECTED_DESTINATION="$choice"
  else
    echo "Invalid choice. Please select a valid destination type."
    select_destination
  fi
}

# Function to download file using aria2c
download_file() {
  local destination_type="$1"
  local url="$2"
  local file_name=$(basename "$url")
  local destination_path="${BASE_DIRECTORIES[$destination_type]}$file_name"

  # Check if file already exists
  if [ -e "$destination_path" ]; then
    read -p "File '$file_name' already exists. Do you want to overwrite it? (y/n): " overwrite_choice
    if [ "$overwrite_choice" != "y" ]; then
      echo "Download aborted."
      exit 1
    fi
  fi

  # Start download in the background
  aria2c --dir="${BASE_DIRECTORIES[$destination_type]}" "$url" &
  echo "Download of '$file_name' started in the background. It will continue even if you close your shell/ssh session."
}

# Main function
dl() {
  local destination_type="$1"
  local url="$2"

  # If destination type is not provided, prompt user for input
  if [ -z "$destination_type" ]; then
    select_destination
  fi

  # Download the file
  download_file "$SELECTED_DESTINATION" "$url"
}

# Example usage:
# dl lora https://civitai.com/api/download/models/181836
# dl textgen https://huggingface.co/liuhaotian/llava-v1.5-13b/blob/main/pytorch_model-00001-of-00003.bin
