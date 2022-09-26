#!/usr/bin/env bash
##########################################################################
# Title      :	chtext - change text in multiple files
# Author     :	Heiner Steven <heiner.steven@odn.de>
# Date       :	1993-05-13
# Requires   :
# Category   :	Text Utilities
# SCCS-Id.   :	@(#) chtext	1.6 04/07/08
##########################################################################
# Description
#    -	This script basically does the following:
#	    sed 's/old/new/g' < IN > TMP && mv TMP IN
#
# Caveats
#    o	Should have an option to enable the special meaning of "&"
#	in the "sed" expression (suggested by Douglas Kramer)
##########################################################################

PN=$(basename "$0") # Program name
VER='1.6'

usage() {
    echo >&2 "$PN - change text in multiple files, $VER
Heiner Steven 1993-2004; Public Domain

usage: $PN [-fq] [-s searchpat] [-n newtext] file [...]
    -s:  search expression that should be replaced
    -n:  new text
    -f:  remove (instead replace) search expression
    -q:  quiet mode

If the search pattern or the new text is not specified
on the commandline, $PN will prompt for it."
    exit 1
}

msg() {
    [ "$Quiet" = true ] && return 0
    echo >&2 "$PN:" "$@"
}

# GetStr (prompt, varname)
# Note: "call by name", varname is the name of a variable, not a value:
#	Example: file=test.txt; GetStr "file name" file

GetStr() {
    test $# -eq 2 || return 1

    answer=
    echo "$1: \c" # some UNIXes need "echo -n"
    read answer || {
        echo
        exit 1
    }

    eval $2=\$answer # assign new value to variable
    return 0
}

Tmp="cht$$"      # Temporary file
OldText=         # Search pattern
NewText=         # New Text
Interactive=true # Parameter -f
Quiet=false      # Parameter -q

while [ $# -gt 0 ]; do
    case "$1" in
    -s)
        OldText="$2"
        shift
        ;;
    -n)
        [ $# -gt 1 ] && Interactive=false
        NewText="$2"
        shift
        ;;
    -f) Interactive=false ;;
    -q) Quiet=true ;;
    --)
        shift
        break
        ;; # Files will follow
    -*) usage ;;
    *) break ;; # File name(s)
    esac
    shift
done

[ $# -lt 1 ] && usage

if [ -z "$OldText" ] || [ -z "$NewText" ]; then
    if [ "$Quiet" != true ]; then
        echo >&2 "$PN - change text, $VER"
        echo >&2
        msg "Files to change:" "$@"
    fi

    if [ -z "$OldText" ]; then
        GetStr "old text" OldText
        [ -z "$OldText" ] && exit 1
    fi

    if [ -z "$NewText" ] && [ "$Interactive" = true ]; then
        GetStr "new text" NewText
        if [ -z "$NewText" ]; then
            echo >&2 "$PN: Really remove '$OldText' (y/n)? \c"
            read answer || exit 1
            case "$answer" in
            y | true) break ;;
            *) exit 1 ;;
            esac
        fi
    fi
fi

if [ "$OldText" = "$NewText" ]; then
    echo >&2 "$PN: old and new text are identical - no substitution necessary!"
    exit 1
fi

case "$OldText$NewText" in
**)
    echo >&2 "
$PN: ERROR: text to change cannot contain an ^A (ASCII 1) character,
because it is used internally as a delimiting character"
    exit 1
    ;;
esac

msg "change '$OldText' to '$NewText'"

# We are using NewText on the right side of an "sed" expression, and
# therefore have to protect the special character '&' from being
# interpreted as meaning "the matching text":

NewText=$(
    sed 's/&/\\\\&/g' <<EOT
$NewText
EOT
)
errors=0
for file; do
    [ -f "$file" -a -r "$file" -a -w "$file" ] || {
        echo >&2 "$PN: ERROR: no permisson to change '$file' - ignored"
        errors=$(expr $errors + 1)
        continue
    }

    msg "$file"

    cp -p "$file" "$Tmp" || {
        echo >&2 "$PN: ERROR: could not create temporary file for '$file'"
        errors=$(expr $errors + 1)
        continue
    }

    sed -e 's'"$OldText"''"$NewText"'g' <"$file" >"$Tmp" || {
        echo >&2 "$PN: ERROR: could not change '$file'"
        errors=$(expr $errors + 1)
        continue
    }

    if cmp "$file" "$Tmp" >/dev/null; then
        msg "INFO: file has not changed: $file"
        rm -f "$Tmp" >/dev/null 2>&1
        continue
    fi

    mv "$Tmp" "$file" || {
        echo >&2 "$PN: ERROR: could not rename '$Tmp' to '$file' - file not changed!"
        errors=$(expr $errors + 1)
        continue
    }
done

if [ $errors -ne 0 ]; then
    exit 1
fi
exit 0
