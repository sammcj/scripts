#!/usr/bin/env python3
"""
Script for adding one-off folder exclusions to BackBlaze.

Call it by passing a list of paths you want to exclude as command-line
arguments, e.g.

    python add_backblaze_exclusions.py /path/to/exclude/1 /path/to/exclude/2

It saves a copy of your bzinfo.xml backup rules before editing.

macOS only.

"""

import datetime
import os
import pathlib
import shutil
import subprocess
import sys
from typing import Iterator, List

from lxml import etree


def get_dirs_to_exclude(argv: List[str]) -> Iterator[pathlib.Path]:
    """
    Given a list of command-line arguments (e.g. from sys.argv), get
    a list of directory paths to exclude.
    """
    for dirname in argv:
        path = pathlib.Path(dirname).resolve()

        if not os.path.isdir(path):
            print(f"Skipping {dirname}; no such directory", file=sys.stderr)
            continue

        yield path


def add_exclusion(*, root: etree.ElementTree, exclude_dir: pathlib.Path):
    """
    Given the parsed XML from bzinfo.xml and the path to a directory,
    add that directory to the list of exclusions.
    """
    # The filter inside this XML file is something of the form
    #
    #     <do_backup ...>
    #       <bzdirfilter dir="/path/to/exclude/" whichfiles="none" />
    #       ...
    #     </do_backup>
    #
    # so we want to find this do_backup tag, then add the bzdirfilter elements.
    do_backup_elements = root.xpath(".//do_backup")

    if len(do_backup_elements) != 1:
        raise ValueError("Did not find exactly one <do_backup> element in bzinfo.xml")

    do_backup = do_backup_elements[0]

    # If this directory has already been excluded, we can skip adding it again.
    # Note: directory names are case insensitive.
    already_excluded = {
        dirname.lower()
        for dirname in do_backup.xpath('./bzdirfilter[@whichfiles="none"]/@dir')
    }

    if str(exclude_dir).lower() in already_excluded:
        print(f"{exclude_dir} is already excluded in bzinfo.xml")
        return

    # TODO: Look for the case where a parent is excluded, e.g. if /a/b/c is
    # already excluded, we can safely skip adding an exclusion for /a/b/c/d/e.

    # Create the new exclusion tag.
    dirfilter = etree.SubElement(do_backup, "bzdirfilter")
    dirfilter.set("dir", str(exclude_dir).lower())
    dirfilter.set("whichfiles", "none")

    # Sort the list of exclusions.  This isn't strictly necessary, but makes
    # the file a little easier to read and work with.
    do_backup[:] = sorted(
        do_backup.xpath("./bzdirfilter"), key=lambda f: f.attrib["dir"]
    )


def save_backup_copy(bzinfo_path: str) -> str:
    """
    Save a backup copy of the bzinfo.xml file before making edits.
    """
    today = datetime.datetime.now().strftime("%Y-%m-%d_%H-%m-%S")
    backup_path = f"bzinfo.{today}.xml"

    shutil.copyfile(bzinfo_path, backup_path)
    return backup_path


def restart_backblaze():
    """
    Restart all the BackBlaze processes.
    """
    for cmd in [
        ["sudo", "killall", "bzfilelist"],
        ["sudo", "killall", "bzserv"],
        ["sudo", "killall", "bztransmit"],
        ["killall", "bzbmenu"],
        # The exclusion list doesn't get reloaded in System Preferences
        # when the process restarts; we have to quit and reopen SysPrefs.
        ["killall", "System Preferences"],
        ["open", "-a", "BackBlaze.app"],
    ]:
        subprocess.call(cmd, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    dirs_to_exclude = get_dirs_to_exclude(sys.argv[1:])

    bzinfo_path = "/Volumes/Macintosh HD/Library/Backblaze.bzpkg/bzdata/bzinfo.xml"

    backup_path = save_backup_copy(bzinfo_path)
    print(f"*** Saved backup copy of bzinfo.xml to {backup_path}")

    root = etree.parse(bzinfo_path)

    for exclude_dir in dirs_to_exclude:
        add_exclusion(root=root, exclude_dir=exclude_dir)

    print("*** Writing new exclusions to bzinfo.xml")
    with open(bzinfo_path, "wb") as outfile:
        root.write(outfile, pretty_print=True, xml_declaration=True)

    print("*** Restarting BackBlaze")
    restart_backblaze()

