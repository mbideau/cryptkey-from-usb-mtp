#!/bin/sh
#
# Check that every requirements had been copied inside the initramfs
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

# package name
PACKAGE_NAME=cryptkey-from-usb-mtp

# prefixed paths (like Makefile)
# should be replaced at install time
PREFIX="$PREFIX"/usr/local
SYSCONFDIR="$PREFIX"/etc
LIBDIR="$PREFIX"/lib
SBINDIR="$PREFIX"/sbin
DATAROOTDIR="$PREFIX"/share

# default initramfs file to current kernel one
INITRAMFS_PATH_DEFAULT=/boot/initrd.img-`uname -r`

# main script file
SCRIPT_FILE="$SBINDIR"/cryptkey-from-usb-mtp

# configuration
if [ "$CONFIG_DIR" = '' ]; then
    CONFIG_DIR="$SYSCONFDIR"/$PACKAGE_NAME
fi
DEFAULT_CONFIG_FILE=$CONFIG_DIR/default.conf
LOCAL_CONFIG_FILE=$CONFIG_DIR/local.conf
. "$DEFAULT_CONFIG_FILE"
if [ -r "$LOCAL_CONFIG_FILE" ]; then
    . "$LOCAL_CONFIG_FILE"
fi

# including utils
if [ "$INCLUDE_DIR" = '' ]; then
    INCLUDE_DIR="$LIBDIR"/$PACKAGE_NAME/include
fi
USAGE_INC_FILE="$INCLUDE_DIR"/usage.inc.sh
UTILS_INC_FILE="$INCLUDE_DIR"/utils.inc.sh
. "$UTILS_INC_FILE"

# this script filename
_THIS_FILENAME="`basename "$0"`"


# usage
usage()
{
    USAGE_LEFT_MARGIN='        '
    cat <<ENDCAT

$_THIS_FILENAME - `__tt "Check that every requirements had been copied inside the initramfs"`

`__tt 'USAGE'`

    $_THIS_FILENAME [`__tt 'INITRAMFS_FILE'`]
    $_THIS_FILENAME -h|--help

`__tt 'ARGUMENTS'`

    `__tt 'INITRAMFS_FILE'` (`__tt 'optional'`)
        `__tt "The path to an initramfs file (i.e.: %s)\n
        Default to: '%s'" \
            '/boot/initrd.img-*' '/boot/initrd.img-\`uname -r\`'`

`__tt 'OPTIONS'`
 
    -h|--help    
        `__tt 'Display this help.'`
 
`__tt 'ENVIRONMENT'`
 
ENDCAT
    usage_environment

    cat <<ENDCAT
 
`__tt 'EXAMPLES'`

    `__tt "Check current kernel initramfs"|comment`
    > $_THIS_FILENAME

    `__tt "Check a specific initramfs"|comment`
    > $_THIS_FILENAME /boot/initrd.img-4.18.0-3-amd64

ENDCAT
}

# check path in initramfs (remove '/' at the begining)
# $1  string  the path to check for
# $2  string  the file containing lsinitramfs output
check_path()
{
    _path="`echo "$1"|sed 's#^/##'`"
    _ret=0
    if ! grep -q "$_path" "$2"; then
        debug " missing '$_path'"
        _ret=1
    else
        debug "   OK    '$_path'"
    fi
    return $_ret
}

# check that every requirements had been copied inside the initramfs specified
check_initramfs()
{
    _tmpfile="`mktemp`"
    _error_found=$FALSE
    # list files inside initramfs
    debug "Getting the list of files in initramfs '$1'"
    lsinitramfs "$1" >"$_tmpfile"

    # kernel modules usb and fuse
    for _module in usb-common fuse; do
        if ! check_path "${_module}\.ko" "$_tmpfile"; then
            error "$(__tt "Kernel module '%s' (%s) not found in '%s'" "$_module" "${_module}\.ko" "$1")"
            _error_found=$TRUE
        fi
    done

    # libraries usb and fuse
    for _library in usb fuse; do
        if ! check_path "lib${_library}\(-[0-9.]\+\)\?\.so" "$_tmpfile"; then
            error "$(__tt "Library '%s' (%s) not found in '%s'" "$_library" "lib${_library}\(-[0-9.]\+\)\?\.so" "$1")"
            _error_found=$TRUE
        fi
    done

    # jmtpfs binary
    jmtpf_path="`which jmtpfs`"
    if ! check_path "$jmtpf_path" "$_tmpfile"; then
        error "$(__tt "Binary '%s' (%s) not found in '%s'" 'jmtpfs' "$jmtpf_path" "$1")"
        _error_found=$TRUE
    fi

    # /usr/share/misc/magic directory (required to prevent crashing jmtpfs
    # which depends on its existence, even empty)
    if ! check_path 'usr/share/misc/magic' "$_tmpfile"; then
        error "$(__tt "Directory '%s' (%s) not found in '%s'" 'magic' 'usr/share/misc/magic' "$1")"
        _error_found=$TRUE
    fi

    # keyctl binary (optional)
    keyctl_path="`which keyctl`"
    if ! check_path "$keyctl_path" "$_tmpfile"; then
        warning "$(__tt "Binary '%s' (%s) not found in '%s'" 'keyctl' "$keyctl_path" "$1")"
    fi

    # main script
    if ! check_path "$SCRIPT_FILE" "$_tmpfile"; then
        error "$(__tt "Shell script '%s' not found in '%s'" "$SCRIPT_FILE" "$1")"
        _error_found=$TRUE
    fi

    # includes
    if ! check_path "$UTILS_INC_FILE" "$_tmpfile"; then
        error "$(__tt "Shell include script '%s' not found in '%s'" "$UTILS_INC_FILE" "$1")"
        _error_found=$TRUE
    fi
    if ! check_path "$USAGE_INC_FILE" "$_tmpfile"; then
        error "$(__tt "Shell include script '%s' not found in '%s'" "$USAGE_INC_FILE" "$1")"
        _error_found=$TRUE
    fi
        
    # default configuration file
    if ! check_path "$DEFAULT_CONFIG_FILE" "$_tmpfile"; then
        error "$(__tt "Configuration file '%s' not found in '%s'" "$DEFAULT_CONFIG_FILE" "$1")"
        _error_found=$TRUE
    fi

    # mapping file
    if ! check_path "$MAPPING_FILE" "$_tmpfile"; then
        warning "$(__tt "Configuration file '%s' not found in '%s'" "$MAPPING_FILE" "$1")"
    fi

    # locale suport is not disabled
    if [ "$INITRAMFS_DISABLE_LOCALE" != "$TRUE" ]; then

        # current locale
        _locale=*
        if [ "$LANG" !=  '' ]; then
            _locale="`echo "$LANG"|cut -c -2|tr '[:upper:]' '[:lower:]'`"
        fi

        # check the locales
        if ! check_path "$TEXTDOMAINDIR/$_locale/LC_MESSAGES/${PACKAGE_NAME}.mo" "$_tmpfile"; then
            error "$(__tt "Locale file '%s' not found in '%s'" "$TEXTDOMAINDIR/$_locale/LC_MESSAGES/${PACKAGE_NAME}.mo" "$1")"
            _error_found=$TRUE
        fi
        
        # check gettext binary
        if ! check_path "$GETTEXT" "$_tmpfile"; then
            warning "$(__tt "Binary '%s' (%s) not found in '%s'" 'gettext' "$GETTEXT" "$1")"
        fi

        # include locale-archive build by 'locale-gen' else gettext doesn't work
        if [ -e /usr/lib/locale/locale-archive ]; then
            if ! check_path '/usr/lib/locale/locale-archive' "$_tmpfile"; then
                warning "$(__tt "Locale archive file '%s' not found in '%s'" '/usr/lib/locale/locale-archive' "$1")"
            fi

        # compiled locales
        elif [ -d /usr/lib/locale/$LANG ]; then
            for f in /usr/lib/locale/$LANG/LC_*; do
                if ! check_path "$f" "$_tmpfile"; then
                    warning "$(__tt "Locale file '%s' not found in '%s'" "$f" "$1")"
                fi
            done
        fi

        # copy cryptsetup locales
        if [ -e /usr/share/locale/$_locale/LC_MESSAGES/cryptsetup.mo ]; then
            if ! check_path "/usr/share/locale/$_locale/LC_MESSAGES/cryptsetup.mo" "$_tmpfile"; then
                warning "$(__tt "Cryptsetup's locale file '%s' not found in '%s'" "/usr/share/locale/$_locale/LC_MESSAGES/cryptsetup.mo" "$1")"
            fi
        fi
    fi

    # remove temp file
    rm -f "$_tmpfile" >/dev/null||true

    # on error
    if [ "$_error_found" = "$TRUE" ]; then
        error "$(__tt "To further investigate, you can use this command to list files inside initramfs:\n> %s" "lsinitramfs "'"'"$1"'"')"
        return $FALSE
    fi

    # success
    info "`__tt "OK. Initramfs '%s' seems to contain every thing required." "$1"`"
    return $TRUE
}

# display help
if [ "$1" = '-h' -o "$1" = '--help' ]; then
    . "$USAGE_INC_FILE"
    usage
    usage_bottom
    exit 0
fi

# check initramfs
_initramfs_path="$INITRAMFS_PATH_DEFAULT"
if [ "$2" != '' ]; then
    _initramfs_path="$2"
fi
if [ ! -r "$_initramfs_path" ]; then
    error "$(__tt "Initramfs file '%s' doesn't exist or isn't readable" "$_initramfs_path")"
    exit 2
fi
check_initramfs "$_initramfs_path"

