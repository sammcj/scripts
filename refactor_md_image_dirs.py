import os
import shutil
import re

# Author: Sam McLeod, https://smcleod.net

# This application has two main functions: move_files and update_markdown_links.
# The move_files function moves all files from a source directory and its subdirectories to a destination directory, renaming them to ensure that no two files have the same name.
# It returns a mapping of old file names to new file names. The update_markdown_links function updates all image links in markdown files in a given directory and its subdirectories using a provided file mapping.

# Usage:
# Update the src_dir, dest_dir, markdown_dir, and dry_run variables as needed.

# Example of markdown changes after files are moved:
# Before: ![](BearImages/somedir/bear1.jpg), ![](BearImages/someotherdir/bear1.jpg)
# After: ![](Images/1_bear1.jpg), ![](Images/2_bear1.jpg)

def move_files(src_dir, dest_dir, dry_run=False):
  """Move all files from src_dir and its subdirectories to dest_dir, renaming
  them to ensure that no two files have the same name. Returns a mapping of
  old file names to new file names. If dry_run is True, the files will not
  actually be moved.
  """
  # Create a set to store the names of all the files in dest_dir
  existing_filenames = set()

  # Create an empty file mapping to store the old and new names of the moved files
  file_mapping = {}

    # Create the destination directory if it does not exist
  if not os.path.exists(dest_dir):
    os.makedirs(dest_dir)

  # Iterate through the files in src_dir and its subdirectories
  for dirpath, _, filenames in os.walk(src_dir):
    for filename in filenames:
      # Get the full path of the file
      src_path = os.path.join(dirpath, filename)

      # Skip hidden files
      if filename.startswith("."):
        continue

      # Check if the file exists
      if not os.path.exists(src_path):
        continue

      # Generate a unique name for the file in dest_dir
      dest_filename = filename
      counter = 1
      while dest_filename in existing_filenames:
        dest_filename = f"{counter}_{filename}"
        counter += 1
      existing_filenames.add(dest_filename)

      # Add the file to the file mapping
      file_mapping[filename] = dest_filename

      # Move the file to dest_dir (if not doing a dry run)
      if not dry_run:
        dest_path = os.path.join(dest_dir, dest_filename)
        shutil.move(src_path, dest_path)

  return file_mapping

def update_markdown_links(markdown_dir, src_dir, dest_dir, file_mapping, strip_full_path=True, dry_run=False):
  """Update all image links in markdown files in markdown_dir (recursively)
  using the provided file mapping. If dry_run is True, the links will not
  actually be updated.
  """
  # Compile a regular expression to match image links in markdown files, making sure https:// and http:// links are not matched
  image_link_regex = re.compile(rf"!\[\]\((?!https?://){src_dir}/(.+?)\)", re.IGNORECASE)

  # Iterate through the files in markdown_dir and its subdirectories
  for dirpath, _, filenames in os.walk(markdown_dir):
    for filename in filenames:
      # Check if the file is a markdown file
      if not filename.endswith(".md"):
        continue

      # Read the contents of the file
      file_path = os.path.join(dirpath, filename)
      with open(file_path, "r") as f:
        contents = f.read()

      # Replace image links using the file mapping
      new_contents = image_link_regex.sub(
        lambda match: f"![]({os.path.join(dest_dir, file_mapping.get(match.group(1), match.group(1)))})",
        contents
      )

      # Strip any old directory names from the image links (e.g. "Images/BearImages" -> "Images")
      if strip_full_path:
        new_contents = image_link_regex.sub(
          lambda match: f"![]({os.path.join(dest_dir, os.path.basename(match.group(1)))})",
          new_contents
        )


      # Write the updated contents back to the file (if not doing a dry run)
      if not dry_run:
        with open(file_path, "w") as f:
          f.write(new_contents)

      if dry_run:
        print(f"Would have updated {file_path}.")
        print(f"Old contents: {contents}")
        print(f"New contents: {new_contents}")


def main():
  # Set the source and destination directories
  src_dir = "BearImages"
  dest_dir = "Images"

  # Set the directory containing markdown files
  markdown_dir = "."

  # Set dry_run to True to do a dry run (i.e., only print the updates that would be made)
  dry_run = False

  # Set strip_full_path to True to remove the full path from the image links
  strip_full_path = True

  # Move the files from src_dir to dest_dir
  file_mapping = move_files(src_dir, dest_dir, dry_run=dry_run)

  # Update the links in the markdown files
  update_markdown_links(markdown_dir, src_dir, dest_dir, file_mapping, strip_full_path=strip_full_path, dry_run=dry_run)

if __name__ == "__main__":
  main()

