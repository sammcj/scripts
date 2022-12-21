import os
import re

# Takes an export from Bear notes, puts the markdown files inside their directory that contains the attachments, fixes deep links, cleans up tags containing spaces or slashes and any other common fixes so that the notes can be imported to other applications.

# Replace this with the path to your Bear export directory
export_dir = "."

# Iterate through all markdown files in the export directory
for root, dirs, files in os.walk(export_dir):
    for filename in files:
        if filename.endswith(".md"):

            file_path = os.path.abspath(os.path.join(root, filename))
            file_dir = os.path.dirname(file_path)

            # Read the contents of the markdown file
            with open(file_path, "r") as f:
                contents = f.read()

            # Fix deep links by replacing "[[link]]" with "[link](link)"
            contents = re.sub(r"\[\[(.*?)\]\]", r"[\1](\1)", contents)

            # Clean up tags by replacing spaces with hyphens and removing slashes
            tags = re.findall(r"#(\S+)", contents)
            tags = [tag.replace(" ", "-").replace("/", "") for tag in tags]
            for tag in tags:
                contents = contents.replace("#" + tag, "#" + tag)

            # Save the modified contents back to the file
            with open(file_path, "w") as f:
                f.write(contents)

# Create a directory for each markdown file and move the file and its attachments into it
for root, dirs, files in os.walk(export_dir):
    for filename in files:
        if filename.endswith(".md"):
            file_path = os.path.abspath(os.path.join(root, filename))
            file_dir = os.path.dirname(file_path)
            attachment_dir = os.path.join(file_dir, os.path.splitext(filename)[0])

            # Create the attachment directory
            if not os.path.exists(attachment_dir):
                os.mkdir(attachment_dir)

            # Move the markdown file and its attachments into the attachment directory
            os.rename(file_path, os.path.join(attachment_dir, filename))
            for f in os.listdir(file_dir):
                if f != os.path.basename(attachment_dir):
                    os.rename(os.path.join(file_dir, f), os.path.join(attachment_dir, f))

# Remove empty directories
for root, dirs, files in os.walk(export_dir, topdown=False):
    for dirname in dirs:
        dir_path = os.path.join(root, dirname)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)
