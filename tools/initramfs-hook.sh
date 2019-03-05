#!/bin/sh
#
# Copy required files into initramfs.
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

# including usage and utils
if [ "$INCLUDE_DIR" = '' ]; then
    INCLUDE_DIR="$LIBDIR"/$PACKAGE_NAME/include
fi
USAGE_INC_FILE="$INCLUDE_DIR"/usage.inc.sh
UTILS_INC_FILE="$INCLUDE_DIR"/utils.inc.sh
. "$UTILS_INC_FILE"

# this script filename
_THIS_FILENAME="$(basename "$0")"


# usage
usage()
{
    USAGE_LEFT_MARGIN='        '
    cat <<ENDCAT

$_THIS_FILENAME - $(__tt "Copy '%s' required files inside the initramfs" "$PACKAGE_NAME")

$(__tt 'USAGE')

    $_THIS_FILENAME
    $_THIS_FILENAME prereqs
    $_THIS_FILENAME -h|--help

$(__tt 'ARGUMENTS')

    prereqs    
        $(__tt "Print dependencies")

$(__tt 'OPTIONS')
 
    -h|--help    
        $(__tt 'Display this help.')
 
$(__tt 'ENVIRONMENT')
 
ENDCAT
    usage_environment
}


# order/dependencies
[ "$1" = 'prereqs' ] && echo "usb_common fuse" && exit 0


# display help
if [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
    . "$USAGE_INC_FILE"
    usage
    usage_bottom
    exit 0
fi


# if not enabled
if [ "$INITRAMFS_HOOK_ENABLED" = "$FALSE" ]; then

    # do nothing
    exit 0
fi


# do not fail on errors
set +e


# initramfs hook help functions
. "$INITRAMFS_HOOK_FUNC_FILE"


# copy the script
copy_file 'file' "$SCRIPT_FILE"; [ $? -le 1 ] || exit 2

# copy the includes
copy_file 'file' "$UTILS_INC_FILE"; [ $? -le 1 ] || exit 2
if [ -r "$USAGE_INC_FILE" ]; then
    copy_file 'file' "$USAGE_INC_FILE"; [ $? -le 1 ] || exit 2
fi

# copy default configuration file
copy_file 'file' "$DEFAULT_CONFIG_FILE"; [ $? -le 1 ] || exit 2

# copy local configuration file
if [ -r "$LOCAL_CONFIG_FILE" ]; then
    copy_file 'file' "$LOCAL_CONFIG_FILE"; [ $? -le 1 ] || exit 2
fi

# copy mapping file
if [ -r "$MAPPING_FILE" ]; then
    copy_file 'file' "$MAPPING_FILE"; [ $? -le 1 ] || exit 2
fi

# copy filter files (optional)
for _strategy in whitelist blacklist; do
    if [ -r "$(echo "$MTP_FILTER_FILE"|sed "s/\\..*/.$_strategy/")" ]; then
        copy_file 'file' "$(echo "$MTP_FILTER_FILE"|sed "s/\\..*/.$_strategy/")"; [ $? -le 1 ] || exit 2
    fi
done

# locale suport is not disabled
if [ "$INITRAMFS_DISABLE_LOCALE" != "$TRUE" ]; then

    # current locale
    _locale='*'
    if [ "$LANG" !=  '' ]; then
        _locale="$(echo "$LANG"|cut -c -2|tr '[:upper:]' '[:lower:]')"
    fi

    # copy the locales
    for f in "$TEXTDOMAINDIR"/$_locale/LC_MESSAGES/${PACKAGE_NAME}.mo; do
        copy_file 'file' "$f" # ignore failure here (a missing locale is okay)
    done

    # copy gettext
    if [ "$GETTEXT" != '' ] || [ "$GETTEXT" != "$(which echo)" ]; then
        copy_file 'file' "$GETTEXT" # ignore failure here (if gettext binary is missing it will be replaced by echo)
    fi

    # force locale variables in default configuration file
    for _var in LANG LANGUAGE; do
        eval _force_it=\$INITRAMFS_FORCE_$_var
        eval _current_value=\$$_var
        if [ "$_force_it" = "$TRUE" ] && [ "$_current_value" != '' ]; then
            sed -e "s/^[[:blank:]]*#\\?[[:blank:]]*FORCE_$_var=.*/FORCE_$_var=$_current_value/g" \
                -i "$DESTDIR"/"$DEFAULT_CONFIG_FILE"
        fi
    done

    # include locale-archive build by 'locale-gen' else gettext doesn't work
    if [ -e /usr/lib/locale/locale-archive ]; then

        # be careful: this file can be quite large if it store more than the current locale
        if which localedef >/dev/null 2>&1; then
            _LANG_normalized="$(echo "$LANG"|sed -e 's/UTF-\?\(8\|16\)/utf\1/g' -e 's/UTF/utf/g')"
            if [ "$(localedef --list-archive)" != "$_LANG_normalized" ]; then
                echo "WARNING: the locale-archive contains more than the current locale '$_LANG_normalized' (see 'localedef --list-archive')"
                _locale_archive_size="$(du -sh /usr/lib/locale/locale-archive)"
                echo "WARNING: the current file's size of '/usr/lib/locale/locale-archive' is '$_locale_archive_size'" >&2
            fi
        fi
        copy_file 'file' /usr/lib/locale/locale-archive # ignore failure

    # compiled locales
    elif [ -d /usr/lib/locale/"$LANG" ]; then
        for f in /usr/lib/locale/"$LANG"/LC_*; do
            copy_file 'file' "$f" # ignore failure
        done

    # no locale files found
    else
        echo "WARNING: no locale archive nor files found in /usr/lib/locale. Translation might not work." >&2
    fi

    # copy cryptsetup locales
    if [ -e /usr/share/locale/"$_locale"/LC_MESSAGES/cryptsetup.mo ]; then
        copy_file 'file' /usr/share/locale/"$_locale"/LC_MESSAGES/cryptsetup.mo # ignore failure
    fi
fi

# copy jmtpfs binary
JMTPFS_BIN="$(which jmtpfs 2>/dev/null||echo '/usr/bin/jmtpfs')"
copy_exec "$JMTPFS_BIN" || exit 2

# jmtpfs fail if there are no magic file directory, so we create it (empty)
[ ! -d "$DESTDIR"/usr/share/misc/magic ] && mkdir -p "$DESTDIR"/usr/share/misc/magic || exit 2

# copy keyctl binary (optional), for caching keys
KEYCTL_BIN="$(which keyctl 2>/dev/null||echo '/bin/keyctl')"
[ -x "$KEYCTL_BIN" ] && copy_exec "$KEYCTL_BIN" || exit 2


# clean exit
exit 0

