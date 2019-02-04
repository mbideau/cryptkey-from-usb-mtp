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
# Author : Michael Bideau
# Licence: GPLv3+
#
# Source code, documentation and support:
#   https://github.com/mbideau/cryptkey-from-usb-mtp
#

set -e

# constants
TRUE=0
FALSE=1

# configuration
DEBUG=$FALSE
DISPLAY_KEY_FILE=$FALSE
KEYFILE_BAK=/crypto_keyfile.bin
MOUNT_BASE_DIR=/mnt
CRYPTTAB_FILE=/etc/crypttab
CONFIG_DIR=/etc/`basename "$0" '.sh'`
MAPPING_FILE=$CONFIG_DIR/mapping.conf
MAPPING_FILE_SEP='|'
MAPPING_LINE_REGEXP="^\([[:space:]]*[^$MAPPING_FILE_SEP]\+[[:space:]]*$MAPPING_FILE_SEP\)\{2\}[[:space:]]*[^$MAPPING_FILE_SEP]\+[[:space:]]*\$"
MAPPING_OPTS_REGEXP='^\(pass\([,; ]urlenc\)\?\|urlenc\([,; ]pass\)\?\)\?$'
MTP_FILTER_STRATEGY=blacklist
MTP_FILTER_FILE=$CONFIG_DIR/devices.$MTP_FILTER_STRATEGY
MTP_SLEEP_SEC_BEFORE_WAIT=3
MTP_WAIT_TIME=5
MTP_WAIT_MAX=30
MTP_RETRY_MOUNT_DELAY_SEC=2
KERNEL_CACHE_ENABLED=$TRUE
KERNEL_CACHE_MAX_SIZE_KB=32
KERNEL_CACHE_TIMEOUT_SEC=120

# helper function configuration
INITRAMFS_HOOK_PATH_DEFAULT=/etc/initramfs-tools/hooks/`basename "$0" '.sh'`
INITRAMFS_PATH_DEFAULT=/boot/initrd.img-`uname -r`

# translation
TEXTDOMAIN=messages
export TEXTDOMAIN
#LANGUAGE=fr
#export LANGUAGE

# version and author
VERSION=0.0.1
AUTHOR='Michael Bideau [France]'
HOME_PAGE='https://github.com/mbideau/cryptkey-from-usb-mtp'
MAILING_ADDRESS='mica.devel@gmail.com'
PACKAGE_NAME="`basename "$0" '.sh'`"

# internal constants
_THIS_FILENAME="`basename "$0"`"
_THIS_REALPATH="`realpath "$0"`"
_FLAG_WAITED_FOR_DEVICE_ALREADY=/.mtp-waited-already.flag
_MTP_DEVICE_LIST_OUT=/.mtp_device.lst.out
_JMTPFS_ERROR_LOGFILE=/.jmtpfs.err.log
_FLAG_MTP_DEVICES_TO_SKIP=/.mtp_device_to_skip.lst.txt
_PASSPHRASE_PROTECTED=$FALSE
_PRINTF="`which printf`"
_GETTEXT="`which gettext 2>/dev/null||which echo`"
_USAGE_LEFT_MARGIN='            '
_TEXINFO=$FALSE

# usage
#   ENV: if "$_TEXINFO" is TRUE (0) it produce a Texinfo compatible output
usage()
{
    # pre-translate some redundant strings
    _t_STRING="`_t 'STRING'`"
    _t_PATH="`_t 'PATH'`"
    _t_DM_TARGET="`_t 'DM_TARGET'`"
    _t_KEY_PATH="`_t 'KEY_PATH'`"
    _arg_kfile_name="`_t 'keyfile'`"

    # display the usage (translations are inlined)
    cat <<ENDCAT
 
$_THIS_FILENAME - `_t 'Print a key to STDOUT from a key file stored on a USB MTP device.'`
  
`_t 'USAGE'|texinfo_section`
 
    $_THIS_FILENAME `_t 'OPTIONS'`... [`_t 'keyfile'`]
 
    $_THIS_FILENAME --encode $_t_STRING`texinfo_re`
    $_THIS_FILENAME --decode $_t_STRING
 
    $_THIS_FILENAME --initramfs-hook [$_t_PATH]`texinfo_re`
    $_THIS_FILENAME --check-initramfs [$_t_PATH]
 
    $_THIS_FILENAME --create-filter [$_t_PATH]
 
    $_THIS_FILENAME --check-mapping [$_t_PATH]`texinfo_re`
    $_THIS_FILENAME --add-mapping $_t_DM_TARGET $_t_KEY_PATH [encrypted]
 
    $_THIS_FILENAME [-h|--help]`texinfo_re`
    $_THIS_FILENAME -v|--version
 
    $_THIS_FILENAME --texinfo
 
`_t 'ARGUMENTS'|texinfo_section`
 
`texinfo_item 'TP'`
    `_t 'keyfile'`  (`_t 'optional'`)
$_USAGE_LEFT_MARGIN`_t \
"Is the path to a key file.\n
The argument is optional if the env var %s is specified, required otherwise.\n
It is relative to the device mount point/dir.\n
Quotes ['"'"'"] will be removed at the begining and end.\n
If it starts with '%s' it will be URL decoded.\n
If it starts with '%s' it will be decrypted with '%s' on the file.\n
'%s' and '%s' can be combined in any order, i.e.: '%s' or '%s'." \
    'CRYPTTAB_KEY'    \
    'urlenc:' 'pass:' \
    'cryptsetup open' \
    'urlenc:' 'pass:' \
    'urlenc:pass:De%20toute%20beaut%c3%a9.jpg' \
    'pass:urlenc:De%20toute%20beaut%c3%a9.jpg' \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`_t 'OPTIONS'|texinfo_section`
 
`texinfo_item 'TP'`
    --encode $_t_STRING
$_USAGE_LEFT_MARGIN`_t \
"Encode the STRING to url format and print it.\n
NOTE: Usefull to create a key path without spaces to use into '%s' at the third column." \
    "$CRYPTTAB_FILE" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    --decode $_t_STRING
$_USAGE_LEFT_MARGIN`_t "Decode the STRING with url format then print it."`
 
`texinfo_item 'TP'`
    --initramfs-hook [$_t_PATH]
$_USAGE_LEFT_MARGIN`_t \
"Create an initramfs hook at specified path.\n
PATH is optional. It defaults to: '%s'." \
    "$INITRAMFS_HOOK_PATH_DEFAULT" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    --check-initramfs [$_t_PATH]
$_USAGE_LEFT_MARGIN`_t \
"Check that every requirements had been copied inside the initramfs specified.\n
PATH is optional. It defaults to: '%s'." \
    "$INITRAMFS_PATH_DEFAULT" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    --create-filter [$_t_PATH]
$_USAGE_LEFT_MARGIN`_t \
"Create a filter list based on current available devices (i.e.: produced by '%s').\n
PATH is optional. It defaults to: '%s'." \
    'jmtpfs -l'        \
    "$MTP_FILTER_FILE" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    --add-mapping $_t_DM_TARGET $_t_KEY_PATH [encrypted]
$_USAGE_LEFT_MARGIN`_t \
"Add a mapping between a DM target %s and a key path %s.\n
The key might be encrypted in which case you need to specify it with '%s'.\n
If the key path contains non-alphanum char it will be automatically url-encoded and added option '%s'.\n
The mapping entry will be added to file: '%s'." \
    "$_t_DM_TARGET" \
    "$_t_KEY_PATH"  \
    'encrypted'     \
    'urlenc'        \
    "$MAPPING_FILE" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    --check-mapping [$_t_PATH]
$_USAGE_LEFT_MARGIN`_t \
"Check a mapping file.\n
%s is optional. It defaults to: '%s'." \
    'PATH'          \
    "$MAPPING_FILE" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    -h|--help
$_USAGE_LEFT_MARGIN`_t 'Display this help.'`
 
`texinfo_item 'TP'`
    -v|--version
$_USAGE_LEFT_MARGIN`_t 'Display the version of this script.'`
 
`texinfo_item 'TP'`
    --texinfo
$_USAGE_LEFT_MARGIN`_t 'Produce a Texinfo formatted help (for man pages)'`
 
`_t 'ENVIRONMENT'|texinfo_section`
 
`texinfo_item 'TP'`
    CRYPTTAB_KEY
$_USAGE_LEFT_MARGIN`_t \
"A path to a key file.\n
The env var is optional if the argument '%s' is specified, required otherwise.\n
Same process apply as for the '%s' argument, i.e.: removing quotes, URL decoding and decrypting." \
    "$_arg_kfile_name" \
    "$_arg_kfile_name" \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    crypttarget
$_USAGE_LEFT_MARGIN`_t \
"The target device mapper name (unlocked).\n
It is used to do the mapping with a key if none is specified in the crypttab file, else informative only." \
|indent "$_USAGE_LEFT_MARGIN" 2`
 
`texinfo_item 'TP'`
    cryptsource
$_USAGE_LEFT_MARGIN`_t '(informative only) The disk source to unlock.'`
 
`_t 'FILES'|texinfo_section`
 
`texinfo_item 'TP'`
    $_THIS_REALPATH
$_USAGE_LEFT_MARGIN`_t 'This shell script (to be included in the initramfs)'`
 
`texinfo_item 'TP'`
    $INITRAMFS_HOOK_PATH_DEFAULT
$_USAGE_LEFT_MARGIN`_t 'The default path to initramfs hook'`
 
`texinfo_item 'TP'`
    $MTP_FILTER_FILE
$_USAGE_LEFT_MARGIN`_t 'The path to a list of filtered devices'`
 
`texinfo_item 'TP'`
    $MAPPING_FILE
$_USAGE_LEFT_MARGIN`_t 'The path to a mapping file containing mapping between crypttab DM target entries and key (options and path).'`
 
`_t 'EXAMPLES'|texinfo_section`
 
    `_t "Encode a string to URL format to further add it to '%s'" "$CRYPTTAB_FILE"|comment`"`texinfo_re`
    > $_THIS_FILENAME --encode 'relative/path to/key/file/on/usb/mtp/device'
 
    `_t 'Decode a URL encoded string, just to test'|comment``texinfo_re`
    > $_THIS_FILENAME --decode 'relative/path%20to/key/file/on/usb/mtp/device'
 
    `_t 'Use this script as a standalone shell command to unlock a disk'|comment``texinfo_re`
    > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 `texinfo_escape``texinfo_re`
         $_THIS_REALPATH 'urlenc:M%c3%a9moire%20interne%2fkey.bin' `texinfo_escape``texinfo_re`
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt
 
    `_t "A URL encoded key path, to prevent crashing on spaces and non-alphanum chars, in '%s'" "$CRYPTTAB_FILE"|comment``texinfo_re`
    md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=${_THIS_REALPATH},initramfs
 
    `_t "A URL encoded key path with 'encrypted' option, in '%s'" "$CRYPTTAB_FILE"|comment``texinfo_re`
    md0_crypt  UUID=5163bc36 'urlenc:pass:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=${_THIS_REALPATH},initramfs
 
    `_t "A '%s' entry configuration without any key (key will be specified in a mapping file)" "$CRYPTTAB_FILE"|comment``texinfo_re`
    md0_crypt  UUID=5163bc36   none  luks,keyscript=${_THIS_REALPATH},initramfs
 
    `_t 'Add the mapping between the DM target and the key (encrypted)'|comment``texinfo_re`
    > $_THIS_FILENAME --add-mapping md0_crypt 'Mémoire interne/keyfile.bin' encrypted
 
    `_t "The command above will result in the following mapping entry in '%s'" "$MAPPING_FILE"|comment``texinfo_re`
    md0_crypt | urlenc,pass | M%c3%a9moire%20interne%2fkeyfile.bin
 
    `_t 'Check the mapping file syntax'|comment``texinfo_re`
    > $_THIS_FILENAME --check-mapping
 
    `_t 'Create an initramfs hook to copy all required files in it'|comment``texinfo_re`
    > $_THIS_FILENAME --initramfs-hook
 
    `_t 'Update the content of the initramfs'|comment``texinfo_re`
    > update-initramfs -tuck all
 
    `_t 'Check that every requirements had been copied inside initramfs'|comment``texinfo_re`
    > $_THIS_FILENAME --check-initramfs
 
    `_t 'Reboot and pray hard!'|comment``texinfo_re`
    > reboot'
 
    `_t 'Add a whitelist filter based on currently available MTP devices'|comment``texinfo_re`
    > sed 's/^MTP_FILTER_STRATEGY=.*/MTP_FILTER_STRATEGY=whitelist/' -i "$_THIS_REALPATH"`texinfo_re`
    > $_THIS_FILENAME --create-filter
 
    `_t 'Enable debug mode, update initramfs, check it and reboot'|comment``texinfo_re`
    > sed 's/^DEBUG=.*/DEBUG=\\\$TRUE/' -i "$_THIS_REALPATH"`texinfo_re`
    > update-initramfs -tuck all && $_THIS_FILENAME --check-initramfs && reboot
 
`_t 'AUTHORS'|texinfo_section`
 
    `_t 'Written by'`: $AUTHOR
 
`_t 'REPORTING BUGS'|texinfo_section`
 
    `_t 'Report bugs to'`: <$MAILING_ADDRESS>
 
`_t 'COPYRIGHT'|texinfo_section`
 
    `copyright`
    `license|sed '2,$ s/^/    /'`
    `warranty`
 
`_t 'SEE ALSO'|texinfo_section`
 
    `_t 'Home page'`: <$HOME_PAGE>
 
ENDCAT
}
# display version
version()
{
    echo "$_THIS_FILENAME $_VERSION"
}
# display copyright
copyright()
{
    echo "`_t "Copyright (C) 2019 $AUTHOR."`"
}
# diplay license
license()
{
    echo "`_t "License %s: %s <%s>" 'GPLv3+' 'GNU GPL version 3 or later' 'https://gnu.org/licenses/gpl.html'`"
    echo "`_t "This is free software: you are free to change and redistribute it."`"
}
# diplay warranty
warranty()
{
    echo "`_t "There is NO WARRANTY, to the extent permitted by law."`"
}
# display a texinfo section surrounded by PP and RE items (if $_TEXINFO is $TRUE)
# else display input as is
texinfo_section()
{
    if [ "$_TEXINFO" = "$TRUE" ]; then
        printf '.SH '
    fi
    cat -
}
# display a texinfo item (if $_TEXINFO is $TRUE), else do nothing
# $1  string  the item/MACRO code to print
texinfo_item()
{
    if [ "$_TEXINFO" = "$TRUE" ]; then
        printf '.%s\n' "$1"
    fi
}
# display a texinfo font (if $_TEXINFO is $TRUE), else do nothing
texinfo_font()
{
    if [ "$_TEXINFO" = "$TRUE" ]; then
        printf '\\f%s' "$1"
    fi
}
# display a line break and a texinfo restore (if $_TEXINFO is $TRUE)
texinfo_re()
{
    if [ "$_TEXINFO" = "$TRUE" ]; then
        printf '\n'
    fi
    texinfo_item 'RE'
}
# display an escape charactere (depending on $_TEXINFO being $TRUE)
texinfo_escape()
{
    if [ "$_TEXINFO" = "$TRUE" ]; then
        printf '\\\\\\\\\\'
    else
        printf '\\'
    fi
}
# create the content of an initramfs-tools hook shell script
get_initramfs_hook_content()
{
    cat <<ENDCAT
#!/bin/sh

# order/dependencies
[ "\$1" = 'prereqs' ] && echo "usb_common fuse" && exit 0

# help functions
. /usr/share/initramfs-tools/hook-functions

# copy jmtpfs binary
copy_exec /usr/bin/jmtpfs || exit 2

# jmtpfs fail if there are no magic file directory, so we create it
[ ! -d "\$DESTDIR"/usr/share/misc/magic ] && mkdir -p "\$DESTDIR"/usr/share/misc/magic || exit 2

# copy the script
copy_file 'file' "$_THIS_REALPATH"; [ \$? -le 1 ] || exit 2

# copy keyctl binary (optional), for caching keys
[ -x /bin/keyctl ] && copy_exec /bin/keyctl || exit 2

# copy mapping file
if [ -r "$MAPPING_FILE" ]; then
    copy_file 'file' "$MAPPING_FILE"; [ \$? -le 1 ] || exit 2
fi

# copy filter files (optional)
for _strategy in whitelist blacklist; do
    if [ -r "`echo "$MTP_FILTER_FILE"|sed "s/\..*/.\\\$_strategy/"`" ]; then
        copy_file 'file' "`echo "$MTP_FILTER_FILE"|sed "s/\..*/.\\\$_strategy/"`"; [ \$? -le 1 ] || exit 2
    fi
done

exit 0
ENDCAT
}
# check that every requirements had been copied inside the initramfs specified
check_initramfs()
{
    _tmpfile="`mktemp`"
    _error_found=$FALSE
    # list files inside initramfs
    lsinitramfs "$1" >"$_tmpfile"

    # kernel modules usb and fuse
    for _module in usb-common fuse; do
        if ! grep -q "${_module}\.ko" "$_tmpfile"; then
            error "$(_t "Kernel module '%s' (%s) not found" "$_module" "${_module}\.ko")"
            _error_found=$TRUE
        fi
    done

    # libraries usb and fuse
    for _library in usb fuse; do
        if ! grep -q "lib${_library}\(-[0-9.]\+\)\?\.so" "$_tmpfile"; then
            error "$(_t "Library '%s' (%s) not found" "$_library" "lib${_library}\(-[0-9.]\+\)\?\.so")"
            _error_found=$TRUE
        fi
    done

    # jmtpfs binary
    if ! grep -q 'bin/jmtpfs' "$_tmpfile"; then
        error "$(_t "Binary '%s' (%s) not found" 'jmtpfs' 'bin/jmtpfs')"
        _error_found=$TRUE
    fi

    # /usr/share/misc/magic directory (required to prevent crashing jmtpfs
    # which depends on its existence, even empty)
    if ! grep -q 'usr/share/misc/magic' "$_tmpfile"; then
        error "$(_t "Directory '%s' (%s) not found" 'magic' 'usr/share/misc/magic')"
        _error_found=$TRUE
    fi

    # this script
    if ! grep -q "`basename "$0" '.sh'`" "$_tmpfile"; then
        error "$(_t "Shell script '%s' not found" "\`basename "$0" '.sh'\`")"
        _error_found=$TRUE
    fi

    # keyctl binary (optional)
    if ! grep -q 'bin/keyctl' "$_tmpfile"; then
        warning "$(_t "Binary '%s' (%s) not found" 'keyctl' 'bin/keyctl')"
    fi

    # remove temp file
    rm -f "$_tmpfile" >/dev/null||true

    # on error
    if [ "$_error_found" = "$TRUE" ]; then
        error "$(_t "To further investigate, you can use this command to list files inside initramfs:\n> %s" "lsinitramfs "'"'"$1"'"')"
        return $FALSE
    fi

    # success
    info "`_t "OK. Initramfs '%s' seems to contain every thing required." "$1"`"
    return $TRUE
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
    "$_PRINTF" '%b' "`echo -n "$1"|sed "s/%/\\\\\x/g"`"
}
# print the list of available MTP devices
# return 0 (TRUE) if at least one device is available, else 1 (FALSE)
mtp_device_availables()
{
    jmtpfs -l 2>"$_JMTPFS_ERROR_LOGFILE"|tail -n +2 >"$_MTP_DEVICE_LIST_OUT"
    if [ "$?" -ne $TRUE ]; then
        cat "$_JMTPFS_ERROR_LOGFILE" >&2
    fi
    filter_devices "$_MTP_DEVICE_LIST_OUT"
    cat "$_MTP_DEVICE_LIST_OUT"
    if [ `wc -l "$_MTP_DEVICE_LIST_OUT"|awk '{print $1}'` -gt 0 ]; then
        return $TRUE
    fi
    return $FALSE
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
                if [ `sed -e '/^[[:blank:]]*$/d' -e '/^[[:blank:]]*#/d' "$1"|wc -l|awk '{print $1}'` -gt 0 ]; then

                    # temp file
                    _temp_file="`mktemp`"

                    # for every MTP device listed
                    sed -e '/^[[:blank:]]*$/d' -e '/^[[:blank:]]*#/d' "$1" | while read _line; do
                        _product_id="`  echo "$_line"|awk -F ',' '{print $3}'|trim`"
                        _vendor_id="`   echo "$_line"|awk -F ',' '{print $4}'|trim`"
                        _product_name="`echo "$_line"|awk -F ',' '{print $5}'|trim|simplify_name`"
                        _vendor_name="` echo "$_line"|awk -F ',' '{print $6}'|trim`"

                        _device_in_filter_list="`grep -q "^[[:space:]]*$_vendor_id[[:space:]]*[;,|	][[:space:]]*$_product_id\([[:space:]]\+\|$\)" "$MTP_FILTER_FILE"; echo $?`"

                        # allowed devices are:
                        #   whitelist and device is listed
                        #   or blacklist and device is not listed
                        if [ "$MTP_FILTER_STRATEGY" = "whitelist" -a "$_device_in_filter_list" = "$TRUE" ] \
                        || [ "$MTP_FILTER_STRATEGY" = "blacklist" -a "$_device_in_filter_list" = "$FALSE" ]; then
                            debug "Allowing device '%s' (%s)" "$_vendor_name, $_product_name" "$MTP_FILTER_STRATEGY filter"
                            echo "$_line" >> "$_temp_file"

                        # filtered
                        else
                            warning "$(_t "Excluding device '%s' (%s)" "$_vendor_name, $_product_name" "$MTP_FILTER_STRATEGY filter")"
                        fi
                    done

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
            warning "$(_t "Invalid MTP device filter strategy '%s' (must be: %s)" "$MTP_FILTER_STRATEGY" 'whitelist|blacklist')"
        fi

    # no device file
    else
        error "$(_t "MTP device list file '%s' doesn't exist nor is readable" "$1")"
        return $FALSE
    fi
}
# create a filter list based on currently available devices
create_filter_list()
{
    if ! jmtpfs -l 2>"$_JMTPFS_ERROR_LOGFILE" \
    |tail -n +2                               \
    |awk -F ',' '{print $4","$3" |"$6","$5}'  \
    |trim                                     \
    |sed 's/ MTP (ID[0-9]\+)$//g'; then
        cat "$_JMTPFS_ERROR_LOGFILE" >&2
        error "$(_t "Failed to create filter file '%s'" "$1")"
        return $FALSE
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
        if ! jmtpfs "$1" -o ro -device=$2 >/dev/null 2>"$_JMTPFS_ERROR_LOGFILE"; then
            cat "$_JMTPFS_ERROR_LOGFILE" >&2
            error "$(_t "%s failed to mount device '%s'" "'jmtpfs'" "$3")"
            return $FALSE
        else
            debug "Mounted device '%s'" "$3"
        fi

    # already mounted
    else
        debug "Device '%s' is already mounted" "$3"
    fi
    return $TRUE
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
    for _line in `grep -v '^#\|^[[:space:]]*$' "$1"`; do
        IFS="$IFS_BAK"
        debug "Checking line: '%s'" "$_line"
        if ! echo "$_line"|grep -q "$MAPPING_LINE_REGEXP"; then
            error "$(_t "Invalid line '%s'" "$_line")"
            _parsing_success=$FALSE
        else
            _dm_target="`echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $1}'|trim`"
            _key_opts="` echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $2}'|trim`"
            _key_path="` echo "$_line"|awk -F "$MAPPING_FILE_SEP" '{print $3}'|trim`"
            if [ "$_dm_target" = '' ]; then
                error "$(_t "DM target is empty for mapping line '%s'" "$_line")"
                _parsing_success=$FALSE
            elif ! grep -q "^[[:space:]]*$_dm_target[[:space:]]" "$CRYPTTAB_FILE"; then
                warning "$(_t "DM target '%s' do not match any DM target in '%s'" "$_dm_target" "$CRYPTTAB_FILE")"
            fi
            if [ "$_key_path" = '' ]; then
                error "$(_t "Key path is empty for mapping line '%s'" "$_line")"
                _parsing_success=$FALSE
            fi
            if ! echo "$_key_opts"|grep -q "$MAPPING_OPTS_REGEXP"; then
                error "$(_t "Invalid key options '%s' for mapping line '%s'" "$_key_opts" "$_line")"
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
    fi

    # an entry already exists for this DM target
    _override_mapping=
    if grep -q "^[[:space:]]*$_dm_target[[:space:]]" "$_mapping_file"; then
        warning "$(_t "DM target '%s' already have a mapping" "$_dm_target")"
        while ! echo "$_override_mapping"|grep -q '^[yYnN]$'; do
            info "`_t "Override the mapping for DM target '%s' [Y/n] ?" "$_dm_target"`"
            read _override_mapping
            if [ "$_override_mapping" = '' ]; then
                _override_mapping=Y
            fi
        done
        if [ "$_override_mapping" != 'y' -a "$_override_mapping" != 'Y' ]; then
            info "`_t "Aborting."`"
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
# print the content of the key file specified
use_keyfile()
{
    debug "Using key file '%s'" "$1"
    _backup="`if [ "$1" = "$KEYFILE_BAK" ]; then echo ' backup'; fi`"
    _msg="Unlocking '$crypttarget' with$_backup key file '`basename "$1"`' ..."
    if [ "$DISPLAY_KEY_FILE" = "$FALSE" ]; then
        _msg="Unlocking '$crypttarget' with$_backup key file ..."
    fi
    info "`_t "$_msg"`"
    cat "$1"
}
# fall back helper, that first try a backup key file then askpass
fallback()
{
    debug "Fallback"

    # use backup keyfile (if exists)
    if [ -e "$KEYFILE_BAK" ]; then
        use_keyfile "$KEYFILE_BAK"
        exit 0
    fi

    # fall back to askpass (to manually unlock the device)
    /lib/cryptsetup/askpass "Please manually enter key to unlock disk '$crypttarget'"
    
    exit 0
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
_t()
{
    _t="`"$_GETTEXT" "$1"|tr -d '\n'|trim`"
    shift
    printf "$_t\n" "$@"
}
# indent input (from STDIN)
# $1  string  the string use for indentation (spaces or tabulations)
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
        printf "$@"|sed 's/^/[DEBUG]  /g' >&2
        printf "\n" >&2
    fi
}
info()
{
    echo "$@" >&2
}
warning()
{
    echo "$@"|sed 's/^/WARNING: /g' >&2
}
error()
{
    echo "$@"|sed 's/^/ERROR: /g' >&2
}


# produce a Texinfo formatted help (for man pages)
if [ "$1" = '--texinfo' ]; then
    _TEXINFO=$TRUE

    # remove left margin before calling 'usage' command
    _USAGE_LEFT_MARGIN=

    # get the usage in Texinfo mode (because env var $_TEXINFO is $TRUE)
    _usage="`usage|sed -e '3,$ s/-/\\-/g' -e 's/^[[:blank:]]*$/.PP/g'`"

    # do some tweakings (bold fonts addition and margin removal)
    _section_usage="\\.SH `_t 'USAGE'`"
    _section_environment="\\.SH `_t 'ENVIRONMENT'`"
    _section_synopsis=".SH `_t 'SYNOPSIS'`"
    _usage="`echo "$_usage"|sed -e 's/^[[:blank:]]*//g' \
                                -e '/^'"$_section_usage"'$/,/^'"$_section_environment"'$/ s/\(^\| \)\(\[\)\?\(--\?[^] ]\+\)\(\]\)\?/\1\2\\\\\\\\fB\3\\\\\\\\fR\4/g' \
                                -e 's/\(\\\\\\\\fB[^] ]\+\)|\([^] ]\+\\\\\\\\fR\)/\1\\\\\\\\fR|\\\\\\\\fB\2/g' \
                                -e 's/^'"$_section_usage"'$/'"$_section_synopsis"'/'`"

    # display the tweaked usage with header and name section at the top
    echo ".TH `echo "$_THIS_FILENAME"|tr '[[:lower:]]' '[[:upper:]]'` \"8\" \"`date '+%B %Y'`\" \"$PACKAGE_NAME $VERSION\" \"`_t 'System Administration Utilities'`\""
    echo "`_t 'NAME'|texinfo_section`"
    echo "$_usage"
    exit 0
fi

# display help (if asked or nothing is specified)
if [ "$1" = '-h' -o "$1" = '--help' ] \
|| [ "$1" = '' -o "`echo "$1"|grep -q '\--\?[a-zA-Z]'||echo $TRUE`" != "$TRUE" ] && [ "$CRYPTTAB_KEY" = '' -a "$crypttarget" = '' ]; then
    usage
    exit 0
fi

# display version
if [ "$1" = '-v' -o "$1" = '--version' ]; then
    version
    copyright
    license
    warranty
    exit 0
fi

# url encode/decode (special helper)
if [ "$2" != '' ]; then
    if [ "$1" = '--encode' -o "$1" = '--urlencode' ]; then
        urlencode "$2"
        echo
        exit 0
    elif [ "$1" = '--decode' -o "$1" = '--urldecode' ]; then
        urldecode "$2"
        echo
        exit 0
    fi
fi

# create initramfs hook
if [ "$1" = '--initramfs-hook' ]; then
    _hook_path="$INITRAMFS_HOOK_PATH_DEFAULT"
    if [ "$2" != '' ]; then
        _hook_path="$2"
    fi
    if [ -e "$_hook_path" ]; then
        error "$(_t "Initramfs hook file '%s' already exists" "$_hook_path")"
        exit 2
    fi
    _hook_dir_path="`dirname "$_hook_path"`"
    if [ ! -d "$_hook_dir_path" ]; then
        debug "Creating directory '%s' (mode %s)" "$_hook_dir_path" '0755'
        mkdir -p -m 0755 "$_hook_dir_path"
    fi
    get_initramfs_hook_content > "$_hook_path"
    chmod +x "$_hook_path"
    info "`_t "Initramfs hook shell script created at '%s'." "$_hook_path"`"
    info "`_t "You should execute '%s' now." 'update-initramfs -tuck all'`"
    exit 0
fi

# check initramfs
if [ "$1" = '--check-initramfs' ]; then
    _initramfs_path="$INITRAMFS_PATH_DEFAULT"
    if [ "$2" != '' ]; then
        _initramfs_path="$2"
    fi
    if [ ! -r "$_initramfs_path" ]; then
        error "$(_t "Initramfs file '%s' doesn't exist or isn't readable" "$_initramfs_path")"
        exit 2
    fi
    check_initramfs "$_initramfs_path"
    exit $?
fi

# create filter file
if [ "$1" = '--create-filter' ]; then
    _filter_path="$MTP_FILTER_FILE"
    if [ "$2" != '' ]; then
        _filter_path="$2"
    fi
    if [ -e "$_filter_path" ]; then
        error "$(_t "Filter file '%s' already exists" "$_filter_path")"
        exit 2
    fi
    _filter_dir_path="`dirname "$_filter_path"`"
    if [ ! -d "$_filter_dir_path" ]; then
        debug "Creating directory '%s' (mode %s)" "$_filter_dir_path" '0755'
        mkdir -p -m 0640 "$_filter_dir_path"
    fi
    create_filter_list > "$_filter_path"
    exit 0
fi

# check mapping file
if [ "$1" = '--check-mapping' ]; then
    _mapping_path="$MAPPING_FILE"
    if [ "$2" != '' ]; then
        _initramfs_path="$2"
    fi
    if [ ! -r "$_mapping_path" ]; then
        error "$(_t "Mapping file '%s' doesn't exist or isn't readable" "$_mapping_path")"
        exit 2
    fi
    check_mapping "$_mapping_path"
    exit $?
fi

# add a mapping entry
if [ "$1" = '--add-mapping' ]; then
    if [ "$2" = '' -o "$3" = '' ]; then
        error "$(_t "Too few arguments for option '%s'" '--add-mapping')"
        usage
        exit 1
    fi
    if [ "$4" != '' -a "$4" != 'encrypted' ]; then
        error "$(_t "Invalid argument '%s' for option '%s'" '--add-mapping' "$4")"
        usage
        exit 1
    fi
    if ! grep -q "^[[:space:]]*$2[[:space:]]" "$CRYPTTAB_FILE"; then
        warning "$(_t "DM target '%s' do not match any DM target in '%s'" "$2" "$CRYPTTAB_FILE")"
    fi
    for i in 2 3 4; do
        eval _v=\$$i
        if echo "$_v"|grep -q "$MAPPING_FILE_SEP"; then
            error "$(_t "Value '%s' cannot contain mapping file separator '%s'" "$_v" "$MAPPING_FILE_SEP")"
            exit 2
        fi
    done
    add_mapping "$MAPPING_FILE" "$2" "$3" "$4"
    check_mapping "$MAPPING_FILE"
    exit $?
fi

# display a new line, to distinguish between multiple executions
# (i.e.: with multiple device to decrypt)
echo >&2

# key is specified (either by env var or argument)
if [ "$CRYPTTAB_KEY" = '' -a "$1" != '' ]; then
    CRYPTTAB_KEY="$1"
fi

# key is not specified but the DM target is specified
if [ "$CRYPTTAB_KEY" = '' -a "$crypttarget" != '' ]; then
    debug "No CRYPTTAB_KEY specified but a DM target '%s'" "$crypttarget"

    # there is a mapping file
    if [ -r "$MAPPING_FILE" ]; then
        debug "Mapping file '%s' found" "$MAPPING_FILE"

        # a line match in the mapping file
        _matching_line="`grep "^[[:space:]]*$crypttarget[[:space:]]" "$MAPPING_FILE"|tail -n 1||true`"
        if [ "$_matching_line" != '' ]; then
            debug "Matching line '%s' found" "$_matching_line"
            _key_opts="` echo "$_matching_line"|awk -F "$MAPPING_FILE_SEP" '{print $2}'|trim`"
            _key_path="` echo "$_matching_line"|awk -F "$MAPPING_FILE_SEP" '{print $3}'|trim`"
            debug "Key options: '%s'" "$_key_opts"
            debug "Key path: '%s'" "$_key_path"

            # build a key value from it
            CRYPTTAB_KEY="$_key_path"
            if [ "$_key_opts" != '' ]; then
                CRYPTTAB_KEY="`echo "$_key_opts"|sed -e 's/[,; ]/:/g' -e 's/:\+/:/g'`:$CRYPTTAB_KEY"
            fi
            debug "New CRYPTTAB_KEY: '%s'" "$CRYPTTAB_KEY"
        fi
    else
        debug "No mapping file '%s' found" "$MAPPING_FILE"
    fi
fi

# key is specified
if [ "$CRYPTTAB_KEY" != '' ]; then

    # remove quoting
    if echo "$CRYPTTAB_KEY"|grep -q '^["'"'"']\|["'"'"']$'; then
        CRYPTTAB_KEY="`echo "$CRYPTTAB_KEY"|sed 's/^["'"'"']*//g;s/["'"'"']*$//g'`"
    fi

    # passphrase protected
    if echo "$CRYPTTAB_KEY"|grep -q '^\(urlenc:\)\?pass:'; then
        CRYPTTAB_KEY="`echo "$CRYPTTAB_KEY"|sed 's/^\(urlenc:\)\?pass:/\1/g'`"
        _PASSPHRASE_PROTECTED=$TRUE
        debug "Key will be passphrase protected"
    fi

    # URL decode (if encoded)
    if echo "$CRYPTTAB_KEY"|grep -q '^urlenc:'; then
        CRYPTTAB_KEY="`echo "$CRYPTTAB_KEY"|sed 's/^urlenc://g'`"
        CRYPTTAB_KEY="`urldecode "$CRYPTTAB_KEY"`"
    fi
fi

# key is still not specified
if [ "$CRYPTTAB_KEY" = '' ]; then

    # directly fallback
    fallback
fi
debug "CRYPTTAB_KEY='$CRYPTTAB_KEY'"

# key file exist and it readable -> use it directly
if [ -r "$CRYPTTAB_KEY" ]; then
    use_keyfile "$CRYPTTAB_KEY"
    exit 0
fi

# check for 'keyctl' binary existence
if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ] && ! which keyctl >/dev/null; then
    warning "$(_t "'%s' binary not found" 'keyctl')"
    warning "$(_t "On Debian you can install it with: > %s" 'apt install keyutils')"
    KERNEL_CACHE_ENABLED=$FALSE
    warning "$(_t "Key caching is disabled")"
fi

# caching is enabled
if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ]; then

    # key has been cached
    for _checksum in shasum md5sum; do
        if which "$_checksum" >/dev/null 2>&1; then
            _key_id="`echo "$CRYPTTAB_KEY"|$_checksum|awk '{print $1}'`"
            break
        fi
    done
    if [ "$_key_id" = '' ]; then
        _key_id="$CRYPTTAB_KEY"
    fi
    debug "Key ID '%s'" "$_key_id"
    _k_id="`keyctl search @u user "$_key_id" 2>/dev/null||true`"
    if [ "$_k_id" != '' ]; then

        # use it
        debug "Using cached key '%s' (%s)" "$_key_id" "$_k_id"
        info "`_t "Unlocking '%s' with cached key '%s' ..." "$crypttarget" "$_k_id"`"
        keyctl pipe "$_k_id"
        exit 0
    fi
fi

# check for 'jmtpfs' binary existence
if ! which jmtpfs >/dev/null; then
    error "$(_t "'%s' binary not found" 'jmtpfs')"
    error "$(_t "On Debian you can install it with: > %s" 'apt install jmtpfs')"
    exit 2
fi

# ensure usb_common and fuse modules are runing
for _module in usb_common fuse; do
    if [ "`modprobe -nv $_module 2>&1||true`" != '' ]; then
        debug "Loading kernel module '%s'" "$_module"
    fi
    modprobe -q $_module
done

# setup flag file to skip devices
if ! touch "$_FLAG_MTP_DEVICES_TO_SKIP"; then
    warning "$(_t "Failed to create file '%s'" "$_FLAG_MTP_DEVICES_TO_SKIP")"
fi

# wait for an MTP device to be available
if [ ! -e "$_FLAG_WAITED_FOR_DEVICE_ALREADY" ]; then
    sleep $MTP_SLEEP_SEC_BEFORE_WAIT >/dev/null
    _device_availables="`mtp_device_availables||true`"
    if [ "$_device_availables" = '' ]; then
        info "`_t "Waiting for an MTP device to become available (max ${MTP_WAIT_MAX}s) ..."`"
        for i in `seq $MTP_WAIT_TIME $MTP_WAIT_TIME $MTP_WAIT_MAX`; do
            _device_availables="`mtp_device_availables||true`"
            if [ "$_device_availables" != '' ]; then
                break
            fi
            debug "Sleeping ${MTP_WAIT_TIME}s"
            sleep $MTP_WAIT_TIME >/dev/null
        done
    fi
    if [ "$_device_availables" = '' ]; then
        warning "$(_t "No MTP device available (after ${MTP_WAIT_MAX}s timeout)")"
    fi
    touch "$_FLAG_WAITED_FOR_DEVICE_ALREADY"
else
    debug "Not waiting for MTP device (already done once)"
fi

# create a file in order to catch the result of the subshell
_result_file="`mktemp`"

# for every MTP device
{ cat "$_MTP_DEVICE_LIST_OUT" | while read _line; do
    debug "Device line: '%s'" "$_line"

    # decompose line data
    _bus_num="`     echo "$_line"|awk -F ',' '{print $1}'|trim`"
    _device_num="`  echo "$_line"|awk -F ',' '{print $2}'|trim`"
    _product_id="`  echo "$_line"|awk -F ',' '{print $3}'|trim`"
    _vendor_id="`   echo "$_line"|awk -F ',' '{print $4}'|trim`"
    _product_name="`echo "$_line"|awk -F ',' '{print $5}'|trim|simplify_name`"
    _vendor_name="` echo "$_line"|awk -F ',' '{print $6}'|trim`"

    # get a unique mount path for this device
    _product_name_nospace="`echo "$_product_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g'`"
    _vendor_name_nospace="`echo "$_vendor_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g'`"
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
        info "`_t "Please unlock the device '%s', then hit enter ... ('s' to skip)" "${_vendor_name}, ${_product_name}"`"
        read unlocked >/dev/null <&3

        # skip unlocking (give up)
        if [ "$unlocked" = 's' -o "$unlocked" = 'S' ]; then
            info "`_t "Skipping unlocking device '%s'" "${_vendor_name}, ${_product_name}"`"

        # device should be unlocked
        else
            sleep 1 >/dev/null

            # stil no access
            if ! ls -alh "$_mount_path" >/dev/null 2>&1; then

                # try unmounting/mounting
                unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"
                sleep $MTP_RETRY_MOUNT_DELAY_SEC >/dev/null
                mount_mtp_device "$_mount_path" "${_bus_num},${_device_num}" "${_vendor_name}, ${_product_name}"||true
            fi
        fi
    fi

    # filesystem is accessible
    if ls -alh "$_mount_path" >/dev/null 2>&1; then
        debug "Device's filesystem is accessible"

    # no access => give up
    else
        warning "$(_t "Filesystem of device '%s' is not accessible" "${_vendor_name}, ${_product_name}")"
        warning "$(_t "Ignoring device '%s' (filesystem unaccessible)" "${_vendor_name}, ${_product_name}")"
        echo "$_device_unique_id" >> "$_FLAG_MTP_DEVICES_TO_SKIP"
        unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"
        continue
    fi

    # try to get the key file
    _keyfile_path="$_mount_path"/"$CRYPTTAB_KEY"
    if [ ! -e "$_keyfile_path" ]; then
        debug "Keyfile '%s' not found" "$_keyfile_path"
        _keyfile_path="`realpath "$_mount_path"/*/"$CRYPTTAB_KEY" 2>/dev/null||true`"
    fi

    # key file found
    if [ "$_keyfile_path" != '' -a -e "$_keyfile_path" ]; then
        debug "Found cryptkey at '%s'" "$_keyfile_path"
        _keyfile_to_use="$_keyfile_path"

        # passphrase protected
        if [ "$_PASSPHRASE_PROTECTED" = "$TRUE" ]; then

            # ensure loop module is loaded
            if [ "`modprobe -nv 'loop' 2>&1||true`" != '' ]; then
                debug "Loading kernel module 'loop'"
            fi
            modprobe -q loop

            # name the device mapper
            _device_mapper_name="`basename "$_keyfile_path"|sed -e 's/\./-/g' -e 's/[^a-zA-Z0-9_+ -]//g;s/[[:blank:]]\+/-/g'`_crypt"
            debug "Device mapper name is: '%s'" "$_device_mapper_name"

            # ask for passphrase
            _key_decrypted=$FALSE
            debug "Key is passphrase protected, so trying to decrypt it by asking the user"
            if ! cryptsetup open --readonly "$_keyfile_path" "$_device_mapper_name" >/dev/null <&3; then
                error "$(_t "Failed to decrypt key '%s' with cryptsetup" "\`basename "$_keyfile_path"\`")"
            elif [ ! -e "/dev/mapper/$_device_mapper_name" ]; then
                error "$(_t "Key decrypted but device mapper '%s' doesn't exists! Bug?" "/dev/mapper/$_device_mapper_name")"
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
            _k_id="`cat "$_keyfile_to_use"|keyctl padd user "$_key_id" @u||true`"

            # caching failed
            if [ "$_k_id" = '' ]; then
                warning "$(_t "Failed to add key '%s' to kernel cache" "$_key_id")"

                # it might be because the data content exceeds the cache max size
                _key_content_size="`du -sk "$_keyfile_to_use"|awk '{print $1}'||true`"
                if [ "$_key_content_size" != '' -a "$_key_content_size" -ge "$KERNEL_CACHE_MAX_SIZE_KB" ]; then
                    warning "$(_t "Key content size '%s' exceeds cache max size of '%s'" "$_key_content_size" "$KERNEL_CACHE_MAX_SIZE_KB")"
                    warning "$(_t "The content for key '%s' cannot be cached" "$_key_id")"
                elif [ "$_key_content_size" != '' ]; then
                    error "$(_t "Uh, I do not understand the cause of failure (bug?), sorry")"
                else
                    error "$(_t "Failed to get file size of '%s'" "$_keyfile_to_use")"
                fi
            fi

            # key successfully cached
            if [ "$_k_id" != '' ]; then

                # set timeout (or remove the key in case of failure)
                if ! keyctl timeout "$_k_id" "$KERNEL_CACHE_TIMEOUT_SEC"; then
                    error "$(_t "Failed to set timeout on cached key '%s'" "$_k_id")"
                    error "$(_t "Removing key '%s' from cache" "$_k_id")"
                    keyctl unlink "$_k_id" @u
                else
                    debug "Cached key at ID '%s'" "$_k_id"
                fi
            else
                error "$(_t "Failed to add key '%s' to kernel cache" "$_key_id")"
            fi
        fi

        # use the key file
        use_keyfile "$_keyfile_to_use"
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
done } 3<&0

# failed to get a key
if [ ! -e "$_result_file" -o "`head -n 1 "$_result_file"|trim`" != "$TRUE" ]; then
    debug "Failed to get a key"
    rm -f "$_result_file"||true

    # fall back
    fallback
fi
rm -f "$_result_file"||true

# vim: set ft=sh ts=4 sw=4 expandtab
