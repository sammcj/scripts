# # Important! This script changes every .md file in the directory where it's run.
# # best to back up your data. Script doesn't back up.

import fileinput, glob, os, pathlib, shutil, sys

# # I've always ran this script in the same directory as the "Obsidian Vault" directory
# # where I've copied my Obsidian Vault to

# Set the directory to loop over
directory = "Obsidian Vault"


# function to move all files to root folder by https://stackoverflow.com/a/39952370
def move_to_root_folder(root_path, cur_path):
    for filename in os.listdir(cur_path):
        if os.path.isfile(os.path.join(cur_path, filename)):
            # if the file already exists, overwrite it
            if os.path.isfile(os.path.join(root_path, filename)):
                    os.remove(os.path.join(root_path, filename))
            else:
                continue

            # if the file is actually a directory, offer to skip or overwrite
            if os.path.isdir(os.path.join(root_path, filename)):
                overwrite = input("File " + filename + " already exists, overwrite? (y/n)")
                if overwrite.lower() == 'y':
                    shutil.rmtree(os.path.join(root_path, filename))
                else:
                    continue

            else:
                continue

            shutil.move(os.path.join(cur_path, filename), os.path.join(root_path, filename))
        elif os.path.isdir(os.path.join(cur_path, filename)):
            move_to_root_folder(root_path, os.path.join(cur_path, filename))
        else:
            continue
    # remove empty folders
    if cur_path != root_path:
        try:
            os.rmdir(cur_path) # remove empty folder
        except:
            print("Folder " + cur_path + " is not empty, skipping.")
            return
    else:
        return


# create tags based on folder structure.
# eg. #2.Areas doesn't work in Bear, so changing . -> -
# then adding a # for every folder structure at the bottom of each note.

for filepath in pathlib.Path(directory).glob('**/*'):
    file = filepath.absolute()
    rel_file = filepath.relative_to(directory)
    only_path = os.path.dirname(rel_file)
    if str(file).endswith('.md'):
        print('processing file > '+str(file))
        tag = str(only_path).replace(" ", "").replace(".","-")
        metadata = '\n\n#'+tag
        # open md file
        with open(file, 'r') as original: data = original.read()

        # updating the image linking from Obsidian to Bear standard
        data = data.replace('![[','![](').replace(']]',')')
        # write md file
        with open(file, 'w') as modified: modified.write(data + metadata)

move_to_root_folder(directory, directory)


# Loop over the files in the directory
for filename in os.listdir(directory):
    # Only consider markdown files
    if filename.endswith(".md"):
        # Open the file
        with open(os.path.join(directory, filename), "r") as f:
            # Read the file's contents into a list of lines
            lines = f.readlines()

        # Initialize a list to store the modified lines
        modified_lines = []

        # Loop over the lines of the file
        i = 0
        while i < len(lines):
            # Check if the current line is a header
            if lines[i].startswith("#"):
                # Check if the next line is also a header
                if i + 1 < len(lines) and lines[i + 1].startswith("#"):
                    # If the headers are the same, skip the duplicate header
                    if lines[i] == lines[i + 1]:
                        i += 1
                    # If the headers are different, add both to the modified lines
                    else:
                        modified_lines.append(lines[i])
                        modified_lines.append(lines[i + 1])
                        i += 2
                # If the next line is not a header, add the current header to the modified lines
                else:
                    modified_lines.append(lines[i])
                    i += 1
            # If the current line is not a header, check if it's a duplicate title without the `#`
            elif i + 1 < len(lines) and lines[i].strip() == lines[i + 1].strip():
                # If it is, skip the duplicate title and add the original title with the `#`
                modified_lines.append(f"# {lines[i].strip()}")
                i += 2
            # If the current line is not a header or a duplicate title, add it to the modified lines
            else:
                modified_lines.append(lines[i])
                i += 1

        # Open the file for writing
        with open(os.path.join(directory, filename), "w") as f:
            # Write the modified lines to the file
            for line in modified_lines:
                f.write(line)
