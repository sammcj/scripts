#!/usr/bin/python
# -----------------------------------------------------------------
# mved.py -- Renames files in the current directory through a text editor.
# Copyright 2007 Michael Kelly (michael@michaelkelly.org)
#
# Edits in 2011 by Hunter Freyer (yt@hjfreyer.com).
#
# This program is released under the terms of the GNU General Public
# License as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

import os
import re
import subprocess
import sys
import tempfile

from optparse import OptionParser, OptionGroup


def GetEditor():
  """Try to get the user's editor from $EDITOR and $VISUAL.

  If those aren't set, fall back on 'vi'.
  """
  return os.getenv('EDITOR') or os.getenv('VISUAL') or 'vi'


def PrintPendingAction(rename_pairs):
  for old, new in rename_pairs:
    if new:
      print 'M %s -> %s' % (old, new)
    else:
      print 'D %s' % old


def PrintWarnings(rename_pairs):
  for old, new in rename_pairs:
    if new.strip() != new:
      print """
WARNING: destination file "%s" has leading or trailing whitespace in its name.""" % new


def Confirm():
  """Prompt the user with message to which they can reply 'y' or 'n'."""
  conf = None

  while conf not in ['y', 'n', '']:
    conf = raw_input('Continue? [y/N] ').lower()

  return conf == 'y'


def DoRename(rename_pairs):
  try:
    for (old, new) in rename_pairs:
      if new:
        os.rename(old, new)
      else:
        os.unlink(old)
  except OSError, e:
    print 'ERROR: Failure during rename.'
    raise


def Mved(directory, list_all):
  try:
    os.chdir(directory)
  except OSError, e:
    print 'ERROR: Could not access directory: %s' % directory
    exit(1)

  files = [f for f in os.listdir(os.getcwd())
           if list_all or (not f.startswith('.'))]
  files.sort()

  tmp = tempfile.NamedTemporaryFile()
  tmp.write('\n'.join(files))
  tmp.flush()

  status = subprocess.call(GetEditor() + ' ' + tmp.name, shell=True)

  if status:
    print 'ERROR: Editor exited with nonzero status (%d).' % status
    exit(status)

  # Rewind file, get new names.
  tmp.seek(0)
  new_files = [f.rstrip('\n\r') for f in tmp.readlines()]

  if len(files) != len(new_files):
    print """\
ERROR: You added or deleted a line. Don't do that. Use blank lines to
delete files."""
    exit(1)

  rename_pairs = [(old, new) for (old, new) in zip(files, new_files)
                  if old != new]

  if not rename_pairs:
    print 'Nothing to do.'
    exit(0)

  PrintPendingAction(rename_pairs)

  PrintWarnings(rename_pairs)

  if not Confirm():
    print 'Aborting'
    exit(0)

  DoRename(rename_pairs)


def main(argv):
  opt_parser = OptionParser(usage='%prog [OPTIONS] [DIRECTORY]')
  opt_parser.add_option(
          '-a', '--all',
          action='store_true',
          dest='list_all',
          help='List all files (including dotfiles; excluding "." and "..").')

  opt_parser.set_defaults(list_all=False)

  (opts, args) = opt_parser.parse_args()

  old_dir = os.getcwd()
  directory = args and args[0] or old_dir

  try:
    Mved(directory, opts.list_all)
  except SystemExit:
    raise
  except:
    print 'ERROR: Unknown error.'
    raise
  finally:
    os.chdir(old_dir)


if __name__ == '__main__':
  main(sys.argv)
