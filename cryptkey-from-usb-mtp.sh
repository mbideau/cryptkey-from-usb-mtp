#!/bin/sh
#
# Print a key to STDOUT from a key file stored on a USB MTP device
# (to unlock encrypted disk).
# Can be piped to 'cryptsetup' (works well as a crypttab's keyscript).
# It supports:
#   * mounting USB MTP devices with 'jmtpfs'
#   * caching keys found with 'keyctl'
#   * using an alternative "backup" keyfile
#   * falling back to 'askpass'
#   * filtering MTP devices by whitelist/blacklist
#   * using a passphrase protected key (decrypted with cryptsetup)
#   * translations
# 
# Standards in this script:
#   POSIX compliance:
#      - http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#      - https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell
#   CLI standards:
#      - https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces
#
# Source code, documentation and support:
#   https://github.com/mbideau/cryptkey-from-usb-mtp
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

# package infos
VERSION=0.0.1
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

# including/sourcing configurations
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

# internal constants
_THIS_FILENAME="$(basename "$0")"
_THIS_REALPATH="$(realpath "$0")"
_FLAG_WAITED_FOR_DEVICE_ALREADY="$TMPDIR"/.mtp-waited-already.flag
_MTP_DEVICE_LIST_OUT="$TMPDIR"/.mtp_device.lst.out
_JMTPFS_ERROR_LOGFILE="$TMPDIR"/.jmtpfs.err.log
_FLAG_MTP_DEVICES_TO_SKIP="$TMPDIR"/.mtp_device_to_skip.lst.txt
_PASSPHRASE_PROTECTED=$FALSE


# display help informations (translated)
usage()
{
    _t_keyfile="$(__tt 'keyfile')"
    cat <<ENDCAT
 
$_THIS_FILENAME - $(__tt 'Print a key to STDOUT from a key file stored on a USB MTP device.')
  
$(__tt 'USAGE')
 
    $_THIS_FILENAME [$_t_keyfile]  
    $_THIS_FILENAME [-h|--help]  
    $_THIS_FILENAME -v|--version
 
$(__tt 'ARGUMENTS')
 
    $(__tt 'keyfile')  ($(__tt 'optional'))    
$USAGE_LEFT_MARGIN$(__tt \
"Is the path to a key file.\\n
The argument is optional if the env var %s is specified, required otherwise.\\n
It is relative to the device mount point/dir.\\n
Quotes ['"'"'"] will be removed at the begining and end.\\n
If it starts with '%s' it will be URL decoded.\\n
If it starts with '%s' it will be decrypted with '%s' on the file.\\n
'%s' and '%s' can be combined in any order, i.e.: '%s' or '%s'." \
    'CRYPTTAB_KEY'    \
    'urlenc:' 'pass:' \
    'cryptsetup open' \
    'urlenc:' 'pass:' \
    'urlenc:pass:De%20toute%20beaut%c3%a9.jpg' \
    'pass:urlenc:De%20toute%20beaut%c3%a9.jpg' \
|indent "$USAGE_LEFT_MARGIN" 2)
 
$(__tt 'OPTIONS')
 
    -h|--help    
$USAGE_LEFT_MARGIN$(__tt 'Display this help.')
 
    -v|--version    
$USAGE_LEFT_MARGIN$(__tt 'Display the version of this script.')
 
$(__tt 'ENVIRONMENT')
 
    CRYPTTAB_KEY    
$USAGE_LEFT_MARGIN$(__tt \
"A path to a key file.\\n
The env var is optional if the argument '%s' is specified, required otherwise.\\n
Same process apply as for the '%s' argument, i.e.: removing quotes, URL decoding and decrypting." \
    "$_t_keyfile" \
    "$_t_keyfile" \
|indent "$USAGE_LEFT_MARGIN" 2)
 
    crypttarget    
$USAGE_LEFT_MARGIN$(__tt \
"The target device mapper name (unlocked).\\n
It is used to do the mapping with a key if none is specified in the crypttab file, else informative only." \
|indent "$USAGE_LEFT_MARGIN" 2)
 
    cryptsource    
$USAGE_LEFT_MARGIN$(__tt '(informative only) The disk source to unlock.')
 
ENDCAT
    usage_environment

    cat <<ENDCAT
 
$(__tt 'FILES')
 
    $(__tt "Note: Paths may have changed, at installation time, by configuration or environment.")
 
    $SBINDIR/$PACKAGE_NAME    
$USAGE_LEFT_MARGIN$(__tt 'Default path to this shell script (to be included in the initramfs).')
 
    $SYSCONFDIR/$PACKAGE_NAME/default.conf    
$USAGE_LEFT_MARGIN$(__tt 'Default path to the default configuration file.')
 
    $SYSCONFDIR/$PACKAGE_NAME/local.conf    
$USAGE_LEFT_MARGIN$(__tt 'Default path to the local configuration file (i.e.: overrides default.conf).')
 
    $SYSCONFDIR/$PACKAGE_NAME/mapping.conf    
$USAGE_LEFT_MARGIN$(__tt 'Default path to the file containing mapping between crypttab DM target and key file.')
 
    $SYSCONFDIR/$PACKAGE_NAME/devices.whitelist    
$USAGE_LEFT_MARGIN$(__tt 'Default path to the list of allowed USB MTP devices.')
 
    $SYSCONFDIR/$PACKAGE_NAME/devices.blacklist
$USAGE_LEFT_MARGIN$(__tt 'Default path to the list of denied USB MTP devices.')
 
    $LIBDIR/$PACKAGE_NAME/tools/    
$USAGE_LEFT_MARGIN$(__tt 'Default path to the directory containg tool scripts to help managing configuration.')
 
    /etc/initramfs-tools/hooks/$PACKAGE_NAME    
$USAGE_LEFT_MARGIN$(__tt 'Path to initramfs hook that inject required files into initramfs.')
 
$(__tt 'EXAMPLES')
 
    $(__tt 'Use this script as a standalone shell command to unlock a disk'|comment)  
    > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 \\  
         $_THIS_REALPATH 'urlenc:M%c3%a9moire%20interne%2fkey.bin' \\  
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt

ENDCAT
}

# URL decode a string (first and unique argument)
urldecode()
{
    "$PRINTF" '%b' "$("$PRINTF" '%s' "$1"|sed "s/%/\\\\\\x/g")"
}

# print the list of available MTP devices
# return 0 (TRUE) if at least one device is available, else 1 (FALSE)
mtp_device_availables()
{
    jmtpfs -l 2>"$_JMTPFS_ERROR_LOGFILE"|tail -n +2 >"$_MTP_DEVICE_LIST_OUT"
    if [ "$?" -ne "$TRUE" ]; then
        cat "$_JMTPFS_ERROR_LOGFILE" >&2
    fi
    filter_devices "$_MTP_DEVICE_LIST_OUT"
    cat "$_MTP_DEVICE_LIST_OUT"
    if [ "$(wc -l "$_MTP_DEVICE_LIST_OUT"|awk '{print $1}')" -gt 0 ]; then
        return "$TRUE"
    fi
    return "$FALSE"
}

# remove devices from a file based on whitelist/blacklist configuration
# $1  string  the path to the device list as produced by 'jmtpfs -l'
filter_devices()
{
    # device file exists and is readable
    if [ -r "$1" ]; then

        # filter strategy is valid
        if echo "$MTP_FILTER_STRATEGY"|grep -q '^\(whitelist\|blacklist\)$'; then

            # filter file exists and is readable
            if [ -r "$MTP_FILTER_FILE" ]; then

                # filter file is not empty
                if [ "$(sed -e '/^[[:blank:]]*$/d' -e '/^[[:blank:]]*#/d' "$1"|wc -l|awk '{print $1}')" -gt 0 ]; then

                    # temp file
                    _temp_file="$(mktemp)"

                    # for every MTP device listed
                    while read -r _line; do
                        if echo "$_line"|grep -q '^[[:space:]]*#\|^[[:space:]]*$'; then
                            continue
                        fi
                        _product_id="$(  echo "$_line"|awk -F ',' '{print $3}'|trim)"
                        _vendor_id="$(   echo "$_line"|awk -F ',' '{print $4}'|trim)"
                        _product_name="$(echo "$_line"|awk -F ',' '{print $5}'|trim|simplify_name)"
                        _vendor_name="$( echo "$_line"|awk -F ',' '{print $6}'|trim)"

                        _device_in_filter_list="$(grep -q "^[[:space:]]*${_vendor_id}[[:space:]]*[;,|	][[:space:]]*${_product_id}\\([[:space:]]\\+\\|$\\)" "$MTP_FILTER_FILE"; echo $?)"

                        # allowed devices are:
                        #   whitelist and device is listed
                        #   or blacklist and device is not listed
                        if { [ "$MTP_FILTER_STRATEGY" = "whitelist" ] && [ "$_device_in_filter_list" = "$TRUE" ]; } \
                        || { [ "$MTP_FILTER_STRATEGY" = "blacklist" ] && [ "$_device_in_filter_list" = "$FALSE" ]; }; then
                            debug "Allowing device '%s' (%s)" "$_vendor_name, $_product_name" "$MTP_FILTER_STRATEGY filter"
                            echo "$_line" >> "$_temp_file"

                        # filtered
                        else
                            warning "$(__tt "Excluding device '%s' (%s)" "$_vendor_name, $_product_name" "$MTP_FILTER_STRATEGY filter")"
                        fi
                    done <"$1"

                    # replace device list by the temp file content
                    mv "$_temp_file" "$1" >/dev/null

                # empty filter file
                else
                    debug "MTP device filter file '%s' is empty" "$MTP_FILTER_FILE"
                fi

            # no filter file
            else
                debug "MTP device filter file '%s' doesn't exist nor is readable" "$MTP_FILTER_FILE"
            fi

        # invalid filter strategy
        else
            warning "$(__tt "Invalid MTP device filter strategy '%s' (must be: %s)" "$MTP_FILTER_STRATEGY" 'whitelist|blacklist')"
        fi

    # no device file
    else
        error "$(__tt "MTP device list file '%s' doesn't exist nor is readable" "$1")"
        return "$FALSE"
    fi
}

# mount a USB MTP device
# $1  string  the mount path
# $2  string  the device number, i.e.: <bus_num>,<device_num>
# $3  string  the device description (only informative)
# return 0 (TRUE) if the device ends up mounted, else 1 (FALSE)
mount_mtp_device()
{
    # create a mount point
    if [ ! -d "$1" ]; then
        debug "Creating mount point '%s'" "$1"
        mkdir -p -m 0700 "$1" >/dev/null
    fi

    # if the device is not already mounted
    if ! mount|grep -q "jmtpfs.*$1"; then

        # mount the device (read-only)
        if ! jmtpfs "$1" -o ro -device="$2" >/dev/null 2>"$_JMTPFS_ERROR_LOGFILE"; then
            cat "$_JMTPFS_ERROR_LOGFILE" >&2
            error "$(__tt "%s failed to mount device '%s'" "'jmtpfs'" "$3")"
            return "$FALSE"
        else
            debug "Mounted device '%s'" "$3"
        fi

    # already mounted
    else
        debug "Device '%s' is already mounted" "$3"
    fi
    return "$TRUE"
}

# unmount a USB MTP device
# $1  string  the mount path
# $2  string  the device description (only informative)
# return 0 (TRUE) if the device ends up unmounted, else 1 (FALSE)
unmount_mtp_device()
{
    # if the device is mounted
    if mount|grep -q "jmtpfs.*$1"; then
        debug "Unmounting device '%s'" "$2"
        umount "$1"
    # not mounted
    else
        debug "Device '%s' is already mounted" "$3"
    fi
    if [ -d "$1" ]; then
        debug "Removing mount point '%s'" "$1"
        rmdir "$1" >/dev/null||true
    fi
}

# print the content of the key file specified
# $1  string  the key file path
# $2  string  the DM target
use_keyfile()
{
    debug "Using key file '%s'" "$1"
    _backup="$(if [ "$1" = "$KEYFILE_BAK" ]; then printf ' '; __tt 'backup'; fi)"
    _msg="$(__tt "Unlocking '%s' with%s key file '%s' ..." "$2" "$_backup" "$(basename "$1")")"
    if [ "$DISPLAY_KEY_FILE" = "$FALSE" ]; then
        _msg="$(__tt "Unlocking '%s' with%s key file ..." "$2" "$_backup")"
    fi
    info "$_msg"
    if [ "$DEBUG" = "$TRUE" ]; then
        debug "Hit '%s' to continue ..." 'enter'
        read -r cont >/dev/null
    fi
    cat "$1"
}

# fall back helper, that first try a backup key file then askpass
# $1  string  the DM target
fallback()
{
    debug "Fallback"

    # use backup keyfile (if exists)
    if [ -e "$KEYFILE_BAK" ]; then
        use_keyfile "$KEYFILE_BAK" "$1"
        exit 0
    fi

    # fall back to askpass (to manually unlock the device)
    "$ASKPASS" "$(__tt "Please manually enter the passphrase to unlock disk '%s'" "$1")"
    
    exit 0
}


# display help (if asked or nothing is specified)
if [ "$1" = '-h' ] || [ "$1" = '--help' ] || [ "$1" = '' ] \
|| [ "$(echo "$1"|grep -q '\--\?[a-zA-Z]'||echo "$TRUE")" != "$TRUE" ] \
&& [ "$CRYPTTAB_KEY" = '' ] && [ "$crypttarget" = '' ]
then
    . "$USAGE_INC_FILE"
    usage
    usage_bottom
    exit 0
fi

# display version
if [ "$1" = '-v' ] || [ "$1" = '--version' ]; then
    . "$USAGE_INC_FILE"
    version
    copyright
    license
    warranty
    exit 0
fi


# display a new line, to distinguish between multiple executions
# (i.e.: with multiple device to decrypt)
echo >&2

# debug LANG, LANGUAGE and TEXTDOMAINDIR
debug "LANG=$LANG, LANGUAGE=$LANGUAGE, TEXTDOMAINDIR=$TEXTDOMAINDIR"

# key is specified (either by env var or argument)
if [ "$CRYPTTAB_KEY" = '' ] && [ "$1" != '' ]; then
    CRYPTTAB_KEY="$1"
fi

# key is not specified but the DM target is specified
if [ "$CRYPTTAB_KEY" = '' ] && [ "$crypttarget" != '' ]; then
    debug "No CRYPTTAB_KEY specified but a DM target '%s'" "$crypttarget"

    # there is a mapping file
    if [ -r "$MAPPING_FILE" ]; then
        debug "Mapping file '%s' found" "$MAPPING_FILE"

        # a line match in the mapping file
        _matching_line="$(grep "^[[:space:]]*${crypttarget}[[:space:]]" "$MAPPING_FILE"|tail -n 1||true)"
        if [ "$_matching_line" != '' ]; then
            debug "Matching line '%s' found" "$_matching_line"
            _key_opts="$( echo "$_matching_line"|awk -F "$MAPPING_FILE_SEP" '{print $2}'|trim)"
            _key_path="$( echo "$_matching_line"|awk -F "$MAPPING_FILE_SEP" '{print $3}'|trim)"
            debug "Key options: '%s'" "$_key_opts"
            debug "Key path: '%s'" "$_key_path"

            # build a key value from it
            CRYPTTAB_KEY="$_key_path"
            if [ "$_key_opts" != '' ]; then
                CRYPTTAB_KEY="$(echo "$_key_opts"|sed -e 's/[,; ]/:/g' -e 's/:\+/:/g'):$CRYPTTAB_KEY"
            fi
            debug "New CRYPTTAB_KEY: '%s'" "$CRYPTTAB_KEY"
        else
            debug "No matching line in mapping file '%s'" "$MAPPING_FILE"
        fi
    else
        debug "No mapping file '%s' found" "$MAPPING_FILE"
    fi
fi

# key is specified
if [ "$CRYPTTAB_KEY" != '' ]; then

    # remove quoting
    if echo "$CRYPTTAB_KEY"|grep -q '^["'"'"']\|["'"'"']$'; then
        CRYPTTAB_KEY="$(echo "$CRYPTTAB_KEY"|sed 's/^["'"'"']*//g;s/["'"'"']*$//g')"
    fi

    # passphrase protected
    if echo "$CRYPTTAB_KEY"|grep -q '^\(urlenc:\)\?pass:'; then
        CRYPTTAB_KEY="$(echo "$CRYPTTAB_KEY"|sed 's/^\(urlenc:\)\?pass:/\1/g')"
        _PASSPHRASE_PROTECTED=$TRUE
        debug "Key will be passphrase protected"
    fi

    # URL decode (if encoded)
    if echo "$CRYPTTAB_KEY"|grep -q '^urlenc:'; then
        CRYPTTAB_KEY="$(echo "$CRYPTTAB_KEY"|sed 's/^urlenc://g')"
        CRYPTTAB_KEY="$(urldecode "$CRYPTTAB_KEY")"
    fi
fi

# key is still not specified
if [ "$CRYPTTAB_KEY" = '' ]; then
    debug "CRYPTTAB_KEY is empty"

    # directly fallback
    fallback "$crypttarget"
fi
debug "CRYPTTAB_KEY='$CRYPTTAB_KEY'"

# key file exist and it readable -> use it directly
if [ -r "$CRYPTTAB_KEY" ]; then
    use_keyfile "$CRYPTTAB_KEY" "$crypttarget"
    exit 0
fi

# check for 'keyctl' binary existence
if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ] && ! which keyctl >/dev/null; then
    warning "$(__tt "'%s' binary not found" 'keyctl')"
    warning "$(__tt "On Debian you can install it with: > %s" 'apt install keyutils')"
    KERNEL_CACHE_ENABLED=$FALSE
    warning "$(__tt "Key caching is disabled")"
fi

# caching is enabled
if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ]; then

    # key has been cached
    for _checksum in shasum md5sum; do
        if which "$_checksum" >/dev/null 2>&1; then
            _key_id="$(echo "$CRYPTTAB_KEY"|$_checksum|awk '{print $1}')"
            break
        fi
    done
    if [ "$_key_id" = '' ]; then
        _key_id="$CRYPTTAB_KEY"
    fi
    debug "Key ID '%s'" "$_key_id"
    _k_id="$(keyctl search @u user "$_key_id" 2>/dev/null||true)"
    if [ "$_k_id" != '' ]; then

        # use it
        debug "Using cached key '%s' (%s)" "$_key_id" "$_k_id"
        info "$(__tt "Unlocking '%s' with cached key '%s' ..." "$crypttarget" "$_k_id")"
        keyctl pipe "$_k_id"
        exit 0
    fi
fi

# check for 'jmtpfs' binary existence
if ! which jmtpfs >/dev/null; then
    error "$(__tt "'%s' binary not found" 'jmtpfs')"
    error "$(__tt "On Debian you can install it with: > %s" 'apt install jmtpfs')"
    exit 2
fi

# ensure usb_common and fuse modules are runing
for _module in usb_common fuse; do
    if [ "$(modprobe -nv $_module 2>&1||true)" != '' ]; then
        debug "Loading kernel module '%s'" "$_module"
    fi
    modprobe -q "$_module"
done

# setup flag file to skip devices
if ! touch "$_FLAG_MTP_DEVICES_TO_SKIP"; then
    warning "$(__tt "Failed to create file '%s'" "$_FLAG_MTP_DEVICES_TO_SKIP")"
fi

# wait for an MTP device to be available
if [ ! -e "$_FLAG_WAITED_FOR_DEVICE_ALREADY" ]; then
    sleep "$MTP_SLEEP_SEC_BEFORE_WAIT" >/dev/null
    _device_availables="$(mtp_device_availables||true)"
    if [ "$_device_availables" = '' ]; then
        info "$(__tt "Waiting for an MTP device to become available (max %ss) ..." "${MTP_WAIT_MAX}")"
        for i in $(seq "$MTP_WAIT_TIME" "$MTP_WAIT_TIME" "$MTP_WAIT_MAX"); do
            _device_availables="$(mtp_device_availables||true)"
            if [ "$_device_availables" != '' ]; then
                break
            fi
            debug "Sleeping ${MTP_WAIT_TIME}s"
            sleep "$MTP_WAIT_TIME" >/dev/null
        done
    fi
    if [ "$_device_availables" = '' ]; then
        warning "$(__tt "No MTP device available (after %ss timeout)" "${MTP_WAIT_MAX}")"
    fi
    touch "$_FLAG_WAITED_FOR_DEVICE_ALREADY"
else
    debug "Not waiting for MTP device (already done once)"
fi

# create a file in order to catch the result of the subshell
_result_file="$(mktemp)"

# for every MTP device
while read -r _line; do
    debug "Device line: '%s'" "$_line"

    # decompose line data
    _bus_num="$(     echo "$_line"|awk -F ',' '{print $1}'|trim)"
    _device_num="$(  echo "$_line"|awk -F ',' '{print $2}'|trim)"
    _product_id="$(  echo "$_line"|awk -F ',' '{print $3}'|trim)"
    _vendor_id="$(   echo "$_line"|awk -F ',' '{print $4}'|trim)"
    _product_name="$(echo "$_line"|awk -F ',' '{print $5}'|trim|simplify_name)"
    _vendor_name="$( echo "$_line"|awk -F ',' '{print $6}'|trim)"

    # get a unique mount path for this device
    _product_name_nospace="$(echo "$_product_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g')"
    _vendor_name_nospace="$(echo "$_vendor_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g')"
    _device_unique_id=${_vendor_name_nospace}--${_product_name_nospace}--${_bus_num}-${_device_num}
    _mount_path="$MOUNT_BASE_DIR"/mtp--$_device_unique_id

    # device to skip
    if grep -q "^$_device_unique_id" "$_FLAG_MTP_DEVICES_TO_SKIP"; then
        debug "Skipping device '%s' (listed as skipped already)" "${_vendor_name}, ${_product_name}"
        continue
    fi

    # mount the device
    if ! mount_mtp_device "$_mount_path" "${_bus_num},${_device_num}" "${_vendor_name}, ${_product_name}"; then
        debug "Skipping device '%s' (mount failure)" "${_vendor_name}, ${_product_name}"
        continue
    fi

    # no access to the device's filesystem
    if ! ls -alh "$_mount_path" >/dev/null 2>&1; then
        debug "Device's filesystem is not accessible"

        # assuming the device is locked (and need user manual unlocking)
        # so ask the user to do so, and wait for its input to continue or skip
        info "$(__tt "Please unlock the device '%s', then hit enter ... ('s' to skip)" "${_vendor_name}, ${_product_name}")"
        read -r unlocked >/dev/null <&3

        # skip unlocking (give up)
        if [ "$unlocked" = 's' ] || [ "$unlocked" = 'S' ]; then
            info "$(__tt "Skipping unlocking device '%s'" "${_vendor_name}, ${_product_name}")"

        # device should be unlocked
        else
            sleep 1 >/dev/null

            # stil no access
            if ! ls -alh "$_mount_path" >/dev/null 2>&1; then

                # try unmounting/mounting
                unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"
                sleep "$MTP_RETRY_MOUNT_DELAY_SEC" >/dev/null
                mount_mtp_device "$_mount_path" "${_bus_num},${_device_num}" "${_vendor_name}, ${_product_name}"||true
            fi
        fi
    fi

    # filesystem is accessible
    if ls -alh "$_mount_path" >/dev/null 2>&1; then
        debug "Device's filesystem is accessible"

    # no access => give up
    else
        warning "$(__tt "Filesystem of device '%s' is not accessible" "${_vendor_name}, ${_product_name}")"
        warning "$(__tt "Ignoring device '%s' (filesystem unaccessible)" "${_vendor_name}, ${_product_name}")"
        echo "$_device_unique_id" >> "$_FLAG_MTP_DEVICES_TO_SKIP"
        unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"
        continue
    fi

    # try to get the key file
    _keyfile_path="$_mount_path"/"$CRYPTTAB_KEY"
    if [ ! -e "$_keyfile_path" ]; then
        debug "Keyfile '%s' not found" "$_keyfile_path"
        _keyfile_path="$(realpath "$_mount_path"/*/"$CRYPTTAB_KEY" 2>/dev/null||true)"
    fi

    # key file found
    if [ "$_keyfile_path" != '' ] && [ -e "$_keyfile_path" ]; then
        debug "Found cryptkey at '%s'" "$_keyfile_path"
        _keyfile_to_use="$_keyfile_path"

        # passphrase protected
        if [ "$_PASSPHRASE_PROTECTED" = "$TRUE" ]; then

            # ensure loop module is loaded
            if [ "$(modprobe -nv 'loop' 2>&1||true)" != '' ]; then
                debug "Loading kernel module 'loop'"
            fi
            modprobe -q loop

            # name the device mapper
            _device_mapper_name="$(basename "$_keyfile_path"|sed -e 's/\./-/g' -e 's/[^a-zA-Z0-9_+ -]//g;s/[[:blank:]]\+/-/g')_crypt"
            debug "Device mapper name is: '%s'" "$_device_mapper_name"

            # ask for passphrase
            _key_decrypted=$FALSE
            debug "Key is passphrase protected, so trying to decrypt it by asking the user"
            if ! cryptsetup open --readonly "$_keyfile_path" "$_device_mapper_name" >/dev/null <&3; then
                error "$(__tt "Failed to decrypt key '%s' with cryptsetup" "$(basename "$_keyfile_path")")"
            elif [ ! -e "/dev/mapper/$_device_mapper_name" ]; then
                error "$(__tt "Key decrypted but device mapper '%s' doesn't exists! Bug?" "/dev/mapper/$_device_mapper_name")"
            else
                debug "Key successfully decrypted"
                _key_decrypted=$TRUE
            fi

            # failed to decrypt the key
            if [ "$_key_decrypted" != "$TRUE" ]; then

                # umount the device
                unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"

                # move on
                continue
            fi

            # register the new path
            _keyfile_to_use="/dev/mapper/$_device_mapper_name"
        fi

        # cache the key
        if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ]; then
            _k_id="$(keyctl padd user "$_key_id" @u <"$_keyfile_to_use"||true)"

            # caching failed
            if [ "$_k_id" = '' ]; then
                warning "$(__tt "Failed to add key '%s' to kernel cache" "$_key_id")"

                # it might be because the data content exceeds the cache max size
                _key_content_size="$(du -sk "$_keyfile_to_use"|awk '{print $1}'||true)"
                if [ "$_key_content_size" != '' ] && [ "$_key_content_size" -ge "$KERNEL_CACHE_MAX_SIZE_KB" ]; then
                    warning "$(__tt "Key content size '%s' exceeds cache max size of '%s'" "$_key_content_size" "$KERNEL_CACHE_MAX_SIZE_KB")"
                    warning "$(__tt "The content for key '%s' cannot be cached" "$_key_id")"
                elif [ "$_key_content_size" != '' ]; then
                    error "$(__tt "Uh, I do not understand the cause of failure (bug?), sorry")"
                else
                    error "$(__tt "Failed to get file size of '%s'" "$_keyfile_to_use")"
                fi
            fi

            # key successfully cached
            if [ "$_k_id" != '' ]; then

                # set timeout (or remove the key in case of failure)
                if ! keyctl timeout "$_k_id" "$KERNEL_CACHE_TIMEOUT_SEC"; then
                    error "$(__tt "Failed to set timeout on cached key '%s'" "$_k_id")"
                    error "$(__tt "Removing key '%s' from cache" "$_k_id")"
                    keyctl unlink "$_k_id" @u
                else
                    debug "Cached key at ID '%s'" "$_k_id"
                fi
            else
                error "$(__tt "Failed to add key '%s' to kernel cache" "$_key_id")"
            fi
        fi

        # use the key file
        use_keyfile "$_keyfile_to_use" "$crypttarget"
        echo "$TRUE" > "$_result_file"

        # passphrase protected and key file is a device mapped
        if [ "$_PASSPHRASE_PROTECTED" = "$TRUE" ] && echo "$_keyfile_to_use"|grep -q '^/dev/mapper/'; then

            # close the device mapper
            debug "Closing the device mapper '%s'" "$_keyfile_to_use"
            cryptsetup close "$_keyfile_to_use"
        fi

        # umount the device
        unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"

        # stop process
        exit 0

    elif [ "$_keyfile_path" != '' ]; then
        debug "Keyfile '%s' not found" "$_keyfile_path"
    fi

    # umount the device
    unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"

    # next device
done < "$_MTP_DEVICE_LIST_OUT"

# failed to get a key
if [ ! -e "$_result_file" ] || [ "$(head -n 1 "$_result_file"|trim)" != "$TRUE" ]; then
    debug "Failed to get a key"
    rm -f "$_result_file"||true

    # fall back
    fallback "$crypttarget"
fi
rm -f "$_result_file"||true

# vim: set ft=sh ts=4 sw=4 expandtab
