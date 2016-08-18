#!/bin/sh
# local rsync accellerator w/o the checksum overhead
# GPL copyright 2010 by Joey Hess <joey@kitenet.net>

usage () {
	echo "usage: local-rsync src dest [rsync options]" >&2
	exit 1
}

# The src and dest are required to come first to simplify option parsing.
src="$1"
dest="$2"
if [ -z "$src" ] || [ -z "$dest" ] || [ ! -e "$src" ]; then
	usage
fi

# Detect if rsync was asked to be verbose, and we'll be verbose. too.
shift 2
verbose=
for o in "$@"; do
	if [ "x$o" = "x-v" ] || [ "x$o" = "x--verbose" ]; then
		verbose=-v
	fi
done

# Ask rsync to do a dry run and print out what it would do.
# Then look for files being sent, and manually cp them.
# This will be faster than letting rsync do it, for large files,
# because rsync calculates checksums when copying files, which
# can use a lot of CPU.
IFS='
'
for line in $(rsync "$src/" "$dest/" "$@" --dry-run --log-format " do %o %n" |
	grep "^ do " | sed -e 's/^ do //')
do
	IFS=' '
	command="${line%% *}"
	file="${line#* }"
	case "$command" in 
	send)
		if [ -f "$src/$file" ]; then
			rm -rf "$dest/$file"
			mkdir -p "$dest/$(dirname "$file")"
			cp $verbose -a "$src/$file" "$dest/$file"
		fi
	;;
	del.)
		# not implemented; cleanup rsync will handle deletion
	;;
	*)
		echo "unknown line: $line" >&2
		exit 1
	;;
	esac
done

# Now allow rsync to run, to clean up things not handled above.
rsync "$src" "$dest" "$@"
