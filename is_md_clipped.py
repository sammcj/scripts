#!/usr/bin/env python3
import os
import re
import sys

def is_likely_clipped(markdown_file):
  # Read the contents of the file into a string
  with open(markdown_file, 'r') as f:
    contents = f.read()

  # Use regular expressions to search for patterns that are commonly found in clipped markdown files
  # These are just simple heuristics, and they may not be sufficient on their own
  patterns = [
    # r'\[.*\]\(.*\)',  # Link
    r'^>',  # Blockquote
    # External links
    r'https?://.*',
    # raw HTML
    r'<.*>',
    # Gifs
    r'!\[.*\]\(.*\.gif\)',
  ]
  matches = [re.search(pattern, contents) for pattern in patterns]
  # give a score to the file based on the number of matches
  score = sum([1 for match in matches if match])
  # ignore any files that already have the tag #clipped-likely
  already_tagged = re.search(r'#clipped-likely', contents)
  # ignore any files with blockquotes (```, ```python, ```bash, etc.)
  has_blockquote = re.search(r'```', contents)

  # if blockquotes remove 1 from score
  if has_blockquote:
    score -= 1


  # if 'smcleod', 'Sam McLeod' or 'sammcj' (all case insensitive) is found in contents, ignore the files
  if re.search(r'smcleod|Sam McLeod|sammcj', contents, re.IGNORECASE):
    my_username = True
  else:
    my_username = False

  return any(matches) and not already_tagged and not my_username and score >= 2

def add_tag(markdown_file):
  # Read the contents of the file into a list of lines
  with open(markdown_file, 'r') as f:
    lines = f.readlines()

  # Add the tag to the last line
  lines[-1] += ' #clipped-likely\n'

  # Write the lines back to the file
  with open(markdown_file, 'w') as f:
    f.writelines(lines)

def main():
  # Get the directory containing the markdown files
  if len(sys.argv) < 2:
    print('Error: No directory specified')
    sys.exit(1)
  directory = sys.argv[1]

  # Check if the dry-run option is specified
  dry_run = False
  if len(sys.argv) > 2 and sys.argv[2] == '--dry-run':
    dry_run = True

  # Open a log file
  with open('log.txt', 'w') as log_file:
    # Iterate over the markdown files in the directory
    for filename in os.listdir(directory):
      if filename.endswith('.md'):
        filepath = os.path.join(directory, filename)
        if is_likely_clipped(filepath):
          print(f'Adding tag to {filepath}')
          log_file.write(f'Adding tag to {filepath}\n')
          if not dry_run:
            add_tag(filepath)

if __name__ == '__main__':
  main()
