#!/bin/bash
# https://gist.github.com/rmtbb/c77deb7a697b032d374c57cf96aa98c8
# Define the main export folder
export_folder=~/Desktop/iMessages_Export
mkdir -p "$export_folder"

# Part 1: Generate the CSV file
echo "Generating CSV file..."

sqlite3 ~/Library/Messages/chat.db <<EOF
.headers on
.mode csv
.output $export_folder/messages.csv
SELECT
    chat.chat_identifier AS contact,  -- Unique identifier for each conversation or group
    strftime('%Y%m%d', message.date/1000000000 + strftime('%s', '2001-01-01'), 'unixepoch') AS date,
    attachment.filename AS attachment_path,
    message.text AS message
FROM
    message
JOIN
    chat_message_join ON message.rowid = chat_message_join.message_id
JOIN
    chat ON chat_message_join.chat_id = chat.rowid
LEFT JOIN
    message_attachment_join ON message.rowid = message_attachment_join.message_id
LEFT JOIN
    attachment ON message_attachment_join.attachment_id = attachment.rowid
ORDER BY
    contact, date;
EOF

# Check if the CSV file was created successfully
if [ ! -f "$export_folder/messages.csv" ]; then
    echo "Error: messages.csv was not created. Check SQLite command syntax and permissions."
    exit 1
fi

echo "CSV file created at $export_folder/messages.csv."

# Part 2: Use the CSV file to organize files by conversation
echo "Organizing files and links by conversation..."

# Process each line in the CSV file (skip the header)
tail -n +2 "$export_folder/messages.csv" | while IFS=, read -r contact date attachment_path message; do
    # Extract phone numbers from `contact` using regular expression
    phone_numbers=$(echo "$contact" | grep -oE '\b[0-9]{10,}\b' | tr '\n' '-')
    phone_numbers=${phone_numbers%-} # Remove trailing hyphen if it exists

    # If no phone numbers are found, fall back to "Unknown"
    if [ -z "$phone_numbers" ]; then
        convo_folder="$export_folder/Unknown"
        convo_id="Unknown"
    else
        convo_folder="$export_folder/$phone_numbers"
        convo_id="$phone_numbers"
    fi

    # Create the main folder for this contact if it doesn't already exist
    mkdir -p "$convo_folder"

    # Define the paths for subfolders with the conversation ID prepended
    files_folder="$convo_folder/${convo_id} - Files"
    links_folder="$convo_folder/${convo_id} - Links"
    mkdir -p "$files_folder"
    mkdir -p "$links_folder"

    # Organize links (URLs) into a single CSV file per conversation
    if [[ "$message" =~ (http|www\.) ]]; then
        # Define links CSV path with the conversation ID prepended
        links_csv="$links_folder/${convo_id} - links.csv"
        # Append to links.csv with format: "conversation_id,date,url"
        echo "$convo_id,$date,\"$message\"" >>"$links_csv"
    fi

    # Process attachments if available
    if [ -n "$attachment_path" ]; then
        # Truncate attachment filename to 20 characters for the base name + extension
        attachment_name="${attachment_path##*/}"
        base_name="${attachment_name%.*}"
        extension="${attachment_name##*.}"
        truncated_name="${base_name:0:20}.$extension"

        # Prepend the conversation ID to the filename
        final_filename="${convo_id} - $truncated_name"

        # Use find to locate the attachment within the Attachments directory
        attachment_full_path=$(find "$HOME/Library/Messages/Attachments" -type f -name "$attachment_name" 2>/dev/null | head -n 1)

        if [ -f "$attachment_full_path" ]; then
            cp "$attachment_full_path" "$files_folder/$final_filename"
        else
            echo "Warning: Attachment file not found for $attachment_name"
        fi
    fi
done

# Remove empty folders
find "$export_folder" -type d -empty -delete

echo "Files and links organized by conversation. Check $export_folder for the results."
