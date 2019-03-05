#!/bin/sh
#
# Utilities functions
#
#
# Copyright (C) 2019 Michael Bideau [France]
#
# This file is part of cryptkey-from-usb-mtp.
#
# cryptkey-from-usb-mtp is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cryptkey-from-usb-mtp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cryptkey-from-usb-mtp.  If not, see <https://www.gnu.org/licenses/>.
#


# require the following constants to be defined (before)
#  $GETTEXT    : the path to 'gettext' binary (or 'echo' one)

set -e

# pad the string coming from STDIN with spaces at its right/left
# $1  integer the length of the string after padding
# $2  string  (optional) the direction to pad, default to 'right' (else, 'left')
strpad()
{
    _length="$1"
    if ! echo "$_length"|grep -q '^[0-9]\+$'; then
        cat -
    else
        _direction='-'
        if [ "$2" = 'left' ]; then
            _direction=
        fi
        awk '{ printf("%'"${_direction}${_length}"'s\n", $0) }'
    fi
}

# remove spaces at the begining and end of a string
# meant to be used with a piped input
trim()
{
    sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'
}

# remove useless words in device name string
# meant to be used with a piped input
simplify_name()
{
    sed 's/[[:blank:]]*\(MTP\|ID[0-9]\+\)[[:blank:]]*//g;s/[[:blank:]]*([^)]*)[[:blank:]]*$//g'
}

# translate a text and use printf to replace strings
# $1  string  the string to translate
# $.. string  string to substitute to '%s' (see printf format)
__tt()
{
    _t="$("$GETTEXT" "$1"|tr -d '\n'|trim)"
    shift
    printf "$_t\\n" "$@"
}

# indent input (from STDIN)
# $1  string  the string used for indentation (spaces or tabulations)
# $2  number  (optional) a line number to start indenting from (starting from 1)
indent()
{
    _start_from_line=1
    if [ "$2" != '' ] && echo "$2"|grep -q '^[1-9][0-9]*$'; then
        _start_from_line=$2
    fi
    sed "${_start_from_line},\$ s/^/$1/g"
}

# display a comment
comment()
{
    sed 's/^/# /g'
}

# helper function to print messages
debug()
{
    if [ "$DEBUG" = "$TRUE" ]; then
        _fmt="$1"
        shift
        printf "$_fmt\\n" "$@"|sed 's/^/[DEBUG]  /g' >&2
    fi
}
info()
{
    echo "$@" >&2
}
MSG_PREFIX_LOCALIZED_WARNING="$(__tt 'WARNING')"
warning()
{
    echo "$@"|sed "s/^/$MSG_PREFIX_LOCALIZED_WARNING: /g" >&2
}
MSG_PREFIX_LOCALIZED_ERROR="$(__tt 'ERROR')"
error()
{
    echo "$@"|sed "s/^/$MSG_PREFIX_LOCALIZED_ERROR: /g" >&2
}

