#!/bin/sh
#
# Check a mapping file or add a mapping entry
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
UTILS_INC_FILE="$INCLUDE_DIR"/utils.inc.sh
. "$UTILS_INC_FILE"

# this script filename
_THIS_FILENAME="`basename "$0"`"


# usage
usage()
{
    USAGE_LEFT_MARGIN='        '
    _t_MAPPING_FILE="`__tt 'MAPPING_FILE'`"
    cat <<ENDCAT

$_THIS_FILENAME - `__tt "Check a mapping file or add a mapping entry."`

`__tt 'USAGE'`

    $_THIS_FILENAME [$_t_MAPPING_FILE] --check
    $_THIS_FILENAME [$_t_MAPPING_FILE] --add `__tt 'DM_TARGET'` `__tt 'KEYFILE_REL_PATH'` [encrypted]
    $_THIS_FILENAME -h|--help

`__tt 'ARGUMENTS'`

    $_t_MAPPING_FILE (`__tt 'optional'`)
        `__tt "The path to the mapping file.\n
        It default to: '%s'." "$MAPPING_FILE"`

`__tt 'OPTIONS'`

    --check
        `__tt "Check a mapping file.\n
        It is the default behaviour when '%s' is not specified." '--add'`

    --add `__tt 'DM_TARGET'` `__tt 'KEYFILE_REL_PATH'` [encrypted]
        `__tt "Add a mapping entry to the mapping file (created it if required).\n
	A mapping entry is an association between a DM target and a key path."`
        `__tt 'Arguments are'`:
          `__tt 'DM_TARGET'|strpad 25` `__tt "DM target name"`
          `__tt 'KEYFILE_REL_PATH'|strpad 25` `__tt "Keyfile path relative to device filesystem"`
          encrypted `__tt 'optional'|awk '{printf("(%s)", $0)}'|strpad 15` `__tt "The key is encrypted (and will need decryption)"`
	`__tt "If the key path contains non-alphanum char it will be automatically\n
	encoded with the url format."`

    -h|--help    
        `__tt 'Display this help.'`
 
`__tt 'ENVIRONMENT'`
 
ENDCAT
    usage_environment

    cat <<ENDCAT
 
`__tt 'EXAMPLES'`

    `__tt "Check default mapping file"|comment`
    > $_THIS_FILENAME --check

    `__tt "Check a specific mapping file"|comment`
    > $_THIS_FILENAME /tmp/new-mapping.conf.tmp --check

    `__tt "Add a mapping entry to default mapping file.\n
      It will decrypt the Device Mapper target '%s'\n
      with the key file searched at '%s'\n
      on every MTP devices that can be mounted (not filtered out)." \
        'vda1_crypt' 'Mémoire Interne/secret_file.bin'|comment|indent '    ' 2`
    > $_THIS_FILENAME --add vda1_crypt 'Mémoire Interne/secret_file.bin'

    `__tt "Add a mapping entry to a specific mapping file.\n
      Uses an encrypted key. So when before using the key to decrypt\n
      the device, it will first ask a password to decrypt the keyfile."|comment|indent '    ' 2`
    > $_THIS_FILENAME /tmp/new-mapping.conf.tmp --add vda1_crypt 'Mémoire Interne/secret_file.bin' encrypted
    
ENDCAT
}

# check the mapping file syntax and values
# $1  string  the path to the mapping file to check
# return 0 (TRUE) if the mapping is correct, else 1 (FALSE)
check_mapping()
{
    _parsing_success=$TRUE
    debug "Parsing mapping file '%s' ..." "$1"
    IFS_BAK="$IFS"
    IFS="
"
    for _line in `grep -v '^[[:space:]]*#\|^[[:space:]]*$' "$1"`; do
        IFS="$IFS_BAK"
        debug "Checking line: '%s'" "$_line"
        if ! echo "$_line"|grep -q "$_MAPPING_LINE_REGEXP"; then
            error "$(__tt "Invalid line '%s'" "$_line")"
            _parsing_success=$FALSE
        else
            _dm_target="`echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $1}'|trim`"
            _key_opts="` echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $2}'|trim`"
            _key_path="` echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $3}'|trim`"
            if [ "$_dm_target" = '' ]; then
                error "$(__tt "DM target is empty for mapping line '%s'" "$_line")"
                _parsing_success=$FALSE
            elif ! grep -q "^[[:space:]]*$_dm_target[[:space:]]" "$CRYPTTAB_FILE"; then
                warning "$(__tt "DM target '%s' do not match any DM target in '%s'" "$_dm_target" "$CRYPTTAB_FILE")"
            fi
            if [ "$_key_path" = '' ]; then
                error "$(__tt "Key path is empty for mapping line '%s'" "$_line")"
                _parsing_success=$FALSE
            fi
            if ! echo "$_key_opts"|grep -q "$_MAPPING_OPTS_REGEXP"; then
                error "$(__tt "Invalid key options '%s' for mapping line '%s'" "$_key_opts" "$_line")"
                _parsing_success=$FALSE
            fi
        fi
        IFS="
"
    done
    IFS="$IFS_BAK"
    return $_parsing_success
}

# add a mapping entry
# $1  string  the path to the mapping file
# $2  string  the DM target name
# $3  string  the path to the keyfile relative to device filesystem
# $4  string  (optional) 'encrypted' to mean that the key is encrypted
add_mapping()
{
    debug "Adding mapping entry '%s' to file '%s' ..." "$*" "$1"
    _mapping_file="$1"
    _dm_target="$2"
    _key_path="$3"
    _key_encryption="$4"
    _key_opts="`if [ "$_key_encryption" = 'encrypted' ]; then echo 'pass'; fi`"

    # a mapping file doesn't exist
    if [ ! -e "$_mapping_file" ]; then

        # create it
        debug "Creating mapping file '%s'" "$_mapping_file"
        touch "$_mapping_file"
        cat >"$_mapping_file" <<ENDCAT
# generated by $_THIS_FILENAME, `date -R`
#
# List of mappings between Device Mapper target that need decryption
# (i.e.: in /etc/crypttab) and a key file path, relative to an USB
# MTP device's filesystem mount point.
#
# DM target $MAPPING_FILE_SEP options $MAPPING_FILE_SEP Key file path

ENDCAT
    fi

    # an entry already exists for this DM target
    _override_mapping=
    if grep -q "^[[:space:]]*$_dm_target[[:space:]]" "$_mapping_file"; then
        warning "$(__tt "DM target '%s' already have a mapping" "$_dm_target")"
        while ! echo "$_override_mapping"|grep -q '^[yYnN]$'; do
            info "`__tt "Override the mapping for DM target '%s' [Y/n] ?" "$_dm_target"`"
            read _override_mapping
            if [ "$_override_mapping" = '' ]; then
                _override_mapping=Y
            fi
        done
        if [ "$_override_mapping" != 'y' -a "$_override_mapping" != 'Y' ]; then
            info "`__tt "Aborting."`"
            exit 0
        fi
    fi

    # key path needs url-encoding
    if ! echo "$2"|grep -q '^[a-z0-9]\+$'; then
        _key_path="`urlencode "$_key_path"`"
        _key_opts="`if [ "$_key_opts" != '' ]; then echo "$_key_opts,"; fi`urlenc"
        debug "Encoded key path to '%s'" "$_key_path"
        debug "Added 'urlenc' key option"
    fi

    # write the entry to the file
    _line="`echo "$_dm_target $MAPPING_FILE_SEP $_key_opts $MAPPING_FILE_SEP $_key_path"|sed 's/|/\\|/g'`"
    debug "Entry line: '%s'" "$_line"
    if [ "$_override_mapping" = 'y' -o "$_override_mapping" = 'Y' ]; then
        debug "Overriding the mapping for DM target '%s'" "$_dm_target"
        sed "s#^[[:space:]]*$_dm_target[[:space:]].*#$_line#g" -i "$_mapping_file"
    else
        debug "Appending the mapping for DM target '%s'" "$_dm_target"
        echo "$_line" >> "$_mapping_file"
    fi
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


# display help
if [ "$1" = '' -o "$1" = '-h' -o "$1" = '--help' ]; then
    . "$INCLUDE_DIR"/usage.inc.sh
    usage
    usage_bottom
    exit 0
fi

# check mapping file
if [ "$1" = '--check' -o "$1" != '' -a "$2" = '--check' ]; then
    _mapping_path="$MAPPING_FILE"
    if [ "$1" != '--check' -a "$1" != '' ]; then
        _mapping_path="$1"
    fi
    if [ ! -r "$_mapping_path" ]; then
        error "$(__tt "Mapping file '%s' doesn't exist or isn't readable" "$_mapping_path")"
        exit 2
    fi
    check_mapping "$_mapping_path"
    exit $?

# add a mapping entry
elif [ "$1" = '--add' -o "$1" != '' -a "$2" = '--add' ]; then
    _mapping_path="$MAPPING_FILE"
    if [ "$1" != '--add' -a "$1" != '' ]; then
        _mapping_path="$1"
        shift
    fi
    shift
    _dm_target="$1"
    _key_path="$2"
    _encryption="$3"
    if [ "$_dm_target" = '' -o "$_key_path" = '' ]; then
        error "$(__tt "Too few arguments for option '%s'" '--add')"
        usage
        exit 2
    fi
    if [ "$_encryption" != '' -a "$_encryption" != 'encrypted' ]; then
        error "$(__tt "Invalid argument '%s' for option '%s'" '--add' "$_encryption")"
        usage
        exit 2
    fi
    if ! grep -q "^[[:space:]]*$_dm_target[[:space:]]" "$CRYPTTAB_FILE"; then
        warning "$(__tt "DM target '%s' do not match any DM target in '%s'" "$_dm_target" "$CRYPTTAB_FILE")"
    fi
    for _v in 1 2 3; do
        eval _v=\$$i
        if echo "$_v"|grep -q "$MAPPING_FILE_SEP"; then
            error "$(__tt "Value '%s' cannot contain mapping file separator '%s'" "$_v" "$MAPPING_FILE_SEP")"
            exit 2
        fi
    done
    add_mapping "$_mapping_path" "$_dm_target" "$_key_path" "$_encryption"
    check_mapping "$_mapping_path"
    exit $?

# invalid options
else
    error "$(__tt "Invalid options")"
    . "$INCLUDE_DIR"/usage.inc.sh
    usage
    exit 2
fi

