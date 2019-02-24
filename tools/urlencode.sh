#!/bin/sh
#
# Encode/decode a string to/from the URL format
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


set -e

# use printf binary
PRINTF="`which printf`"

# this script filename
_THIS_FILENAME="`basename "$0"`"

# usage
usage()
{
    cat <<ENDCAT

$_THIS_FILENAME - Encode/decode a string to/from the URL format.

USAGE

    $_THIS_FILENAME STRING
    $_THIS_FILENAME -d|--decode STRING
    $_THIS_FILENAME -h|--help

ENDCAT
}

# URL encode a string (first and unique argument)
# inspired/copied from here: https://stackoverflow.com/a/10660730
urlencode()
{
    _strlen="`echo -n "$1"|wc -c`"
    _encoded=
    for _pos in `seq 1 $_strlen`; do
        _c=`echo -n "$1"|cut -c $_pos`
        case "$_c" in
            [-_.a-zA-Z0-9] ) _o="$_c" ;;
            * )              _o="`printf '%%%02x' "'$_c'"`" ;;
        esac
        _encoded="${_encoded}$_o"
    done
    echo -n "$_encoded"
}
# URL decode a string (first and unique argument)
urldecode()
{
    "$PRINTF" '%b' "`echo -n "$1"|sed "s/%/\\\\\x/g"`"
}

# display help
if [ "$1" = '' -o "$1" = '-h' -o "$1" = '--help' ]; then
    usage
    exit 0
fi

# decode the string
if [ "$1" = '-d' -o "$1" = '--decode' ]; then
	urldecode "$2"
	echo

# encode the string
else
	urlencode "$1"
	echo
fi

