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
# 
# Author : Michael Bideau
# Licence: GPL v3.0
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
MOUNT_BASE_DIR=/mnt
KEYFILE_BAK=/crypto_keyfile.bin
MTP_FILTER_STRATEGY=blacklist
MTP_FILTER_FILE=/etc/`basename "$0" '.sh'`/devices.$MTP_FILTER_STRATEGY
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

# internal constants
_FLAG_WAITED_FOR_DEVICE_ALREADY=/.mtp-waited-already.flag
_MTP_DEVICE_LIST_OUT=/.mtp_device.lst.out
_JMTPFS_ERROR_LOGFILE=/.jmtpfs.err.log
_FLAG_MTP_DEVICES_TO_SKIP=/.mtp_device_to_skip.lst.txt
_PASSPHRASE_PROTECTED=$FALSE
_PRINTF="`which printf`"

# usage
usage()
{
    cat <<ENDCAT

Print a key to STDOUT from a key file stored on a USB MTP device.

USAGE: `basename "$0"`  OPTIONS  [keyfile]

ARGUMENTS:

  keyfile    optional      Is the path to a key file.
                           The argument is optional if the env var CRYPTTAB_KEY
                           is specified, required otherwise.
                           It is relative to the device mount point/dir.
                           Quotes ['"] will be removed at the begining and end.
                           If it starts with 'urlenc:' it will be URL decoded.
                           If it starts with 'pass:' it will be decrypted with
                           'cryptsetup open' on the file.
                           'urlenc: and 'pass:' can be combined in any order, 
                           i.e.: 'urlenc:pass:De%20toute%20beaut%c3%a9.jpg'
                              or 'pass:urlenc:De%20toute%20beaut%c3%a9.jpg'.
OPTIONS:

  -h|--help                Display this help.

  --encode STRING          When specified, expext a string as unique argument.
                           The string will be URL encoded and printed.
                           NOTE: Usefull to create a key path without spaces
                           to use into /etc/crypttab at the third column.

  --decode STRING          When specified, expext a string as unique argument.
                           The string will be URL decoded and printed.

  --initramfs-hook [PATH]  Create an initramfs hook to path.
                           PATH is optional. It defaults to:
                             '$INITRAMFS_HOOK_PATH_DEFAULT'.

  --check-initramfs [PATH] Check that every requirements had been copied
                           inside the initramfs specified.
                           PATH is optional. It defaults to:
                             '$INITRAMFS_PATH_DEFAULT'.

  --create-filter [PATH]   Create a filter list based on current available
                           devices (i.e.:produced by 'jmtpfs -l').
                           PATH is optional. It defaults to:
                             '$MTP_FILTER_FILE'.

ENV:

  CRYPTTAB_KEY             A path to a key file.
                           The env var is optional if the argument 'keyfile'
                           is specified, required otherwise.
                           Same process apply as for the 'keyfile' argument,
                           i.e.: removing quotes, URL decoding and decrypting.

  cryptsource              (informative only) The disk source to unlock.

  crypttarget              (informative only) The target device mapper name unlocked.


FILES:

  `realpath "$0"`
                           This shell script (to be included in the initramfs)

  $INITRAMFS_HOOK_PATH_DEFAULT
                           The default path to initramfs hook

  $MTP_FILTER_FILE
                           The path to a list of filtered devices (whitelist/blacklist)


EXAMPLES:

  # encoding a string to further add it to /etc/crypttab
  > `basename "$0"` --encode 'relative/path to/key/file/on/usb/mtp/device'

  # decode a URL encoded string, just to test
  > `basename "$0"` --decode 'relative/path%20to/key/file/on/usb/mtp/device'

  # used as a standalone shell command to unlock a disk
  > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 \\
    `realpath "$0"` 'urlenc:M%c3%a9moire%20interne%2fkey.bin'    \\
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt

  # a crypttab entry configuration URL encoded to prevent crashing on spaces and UTF8 chars
  md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=`realpath "$0"`,initramfs

  # a crypttab entry configuration URL encoded and passphrase protected
  md0_crypt  UUID=5163bc36 'urlenc:pass:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=`realpath "$0"`,initramfs

  # create an initramfs hook to copy all required files (i.e.: 'jmtpfs') in it
  > `basename "$0"` --initramfs-hook

  # update the content of the initramfs
  > update-initramfs -tuck all

  # check that every requirements had been copied inside initramfs
  > `basename "$0"` --check-initramfs

  # reboot and pray hard! ^^'
  > reboot
  
  # add a whitelist filter based on currently available MTP devices
  > sed 's/^MTP_FILTER_STRATEGY=.*/MTP_FILTER_STRATEGY=whitelist/' -i `realpath "$0"`
  > `basename "$0"` --create-filter

  # enable debug mode, update initramfs, check it and reboot
  > sed 's/^DEBUG=.*/DEBUG=\\$TRUE/' -i `realpath "$0"`
  > update-initramfs -tuck all && `basename "$0"` --check-initramfs && reboot

ENDCAT
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
copy_file 'file' "`realpath "$0"`"; [ \$? -le 1 ] || exit 2

# copy keyctl binary (optional), for caching keys
[ -x /bin/keyctl ] && copy_exec /bin/keyctl || exit 2

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
            error "Kernel module '$_module' (${_module}\.ko) not found"
            _error_found=$TRUE
        fi
    done

    # libraries usb and fuse
    for _library in usb fuse; do
        if ! grep -q "lib${_library}\(-[0-9.]\+\)\?\.so" "$_tmpfile"; then
            error "Library '$_library' (lib${_library}\(-[0-9.]\+\)\?\.so) not found"
            _error_found=$TRUE
        fi
    done

    # jmtpfs binary
    if ! grep -q 'bin/jmtpfs' "$_tmpfile"; then
        error "Binary 'jmtpfs' (bin/jmtpfs) not found"
        _error_found=$TRUE
    fi

    # /usr/share/misc/magic directory (required to prevent crashing jmtpfs
    # which depends on its existence, even empty)
    if ! grep -q 'usr/share/misc/magic' "$_tmpfile"; then
        error "Directory 'magic' (usr/share/misc/magic) not found"
        _error_found=$TRUE
    fi

    # this script
    if ! grep -q "`basename "$0" '.sh'`" "$_tmpfile"; then
        error "Shell script '`basename "$0" '.sh'`' not found"
        _error_found=$TRUE
    fi

    # keyctl binary (optional)
    if ! grep -q 'bin/keyctl' "$_tmpfile"; then
        warning "Binary 'keyctl' (bin/keyctl) not found"
    fi

    # remove temp file
    rm -f "$_tmpfile" >/dev/null||true

    # on error
    if [ "$_error_found" = "$TRUE" ]; then
        error "To further investigate, you can use this command to list files inside initramfs:
> lsinitramfs "'"'"$1"'"'
        return $FALSE
    fi

    # success
    info "OK. Initramfs '$1' seems to contain every thing required."
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
                            debug "Allowing device '$_vendor_name, $_product_name' ($MTP_FILTER_STRATEGY filter)"
                            echo "$_line" >> "$_temp_file"

                        # filtered
                        else
                            warning "Excluding device '$_vendor_name, $_product_name' ($MTP_FILTER_STRATEGY filter)"
                        fi
                    done

                    # replace device list by the temp file content
                    mv "$_temp_file" "$1" >/dev/null

                # empty filter file
                else
                    debug "MTP device filter file '$MTP_FILTER_FILE' is empty"
                fi

            # no filter file
            else
                debug "MTP device filter file '$MTP_FILTER_FILE' doesn't exist nor is readable"
            fi

        # invalid filter strategy
        else
            warning "Invalid MTP device filter strategy '$MTP_FILTER_STRATEGY' (must be: whitelist|blacklist)"
        fi

    # no device file
    else
        error "MTP device list file '$1' doesn't exist nor is readable"
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
        error "Failed to create filter file '$1'"
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
        debug "Creating mount point '$1'"
        mkdir -p -m 0700 "$1" >/dev/null
    fi

    # if the device is not already mounted
    if ! mount|grep -q "jmtpfs.*$1"; then

        # mount the device (read-only)
        if ! jmtpfs "$1" -o ro -device=$2 >/dev/null 2>"$_JMTPFS_ERROR_LOGFILE"; then
            cat "$_JMTPFS_ERROR_LOGFILE" >&2
            error "'jmtpfs' failed to mount device '$3'"
            return $FALSE
        else
            debug "Mounted device '$3'"
        fi

    # already mounted
    else
        debug "Device '$3' is already mounted"
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
        debug "Unmounting device '$2'"
        umount "$1"
    # not mounted
    else
        debug "Device '$3' is already mounted"
    fi
    if [ -d "$1" ]; then
        debug "Removing mount point '$1'"
        rmdir "$1" >/dev/null||true
    fi
}
# print the content of the key file specified
use_keyfile()
{
    debug "Using key file '$1'"
    _backup="`if [ "$1" = "$KEYFILE_BAK" ]; then echo ' backup'; fi`"
    _msg="Unlocking '$crypttarget' with$_backup key file '`basename "$1"`' ..."
    if [ "$DISPLAY_KEY_FILE" = "$FALSE" ]; then
        _msg="Unlocking '$crypttarget' with$_backup key file ..."
    fi
    info "$_msg"
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
# meant to be used with a piped input
trim()
{
    sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'
}
# remove useless words in device name string
# meant to be used with a piped input
simplify_name()
{
    sed 's/[[:blank:]]*\(MTP\|ID[0-9]\+\)[[:blank:]]*//g;s/[[:blank:]]*([^)]*)[[:blank:]]*$//g'
}
# helper function to print messages
debug()
{
    if [ "$DEBUG" = "$TRUE" ]; then
        echo $2 "[DEBUG] $1" >&2
    fi
}
info()
{
    echo $2 "$1" >&2
}
warning()
{
    echo $2 "WARNING: $1" >&2
}
error()
{
    echo $2 "ERROR: $1" >&2
}



# display help (if asked)
if [ "$1" = '-h' -o "$1" = '--help' ]; then
    usage
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
        error "Initramfs hook file '$_hook_path' already exists"
        exit 2
    fi
    _hook_dir_path="`dirname "$_hook_path"`"
    if [ ! -d "$_hook_dir_path" ]; then
        mkdir -p -m 0755 "$_hook_dir_path"
    fi
    get_initramfs_hook_content > "$_hook_path"
    chmod +x "$_hook_path"
    info "Initramfs hook shell script created at '$_hook_path'."
    info "You should execute 'update-initramfs -tuck all' now."
    exit 0
fi

# check initramfs
if [ "$1" = '--check-initramfs' ]; then
    _initramfs_path="$INITRAMFS_PATH_DEFAULT"
    if [ "$2" != '' ]; then
        _initramfs_path="$2"
    fi
    if [ ! -r "$_initramfs_path" ]; then
        error "Initramfs file '$_initramfs_path' doesn't exist or isn't readable"
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
        error "Filter file '$_filter_path' already exists"
        exit 2
    fi
    _filter_dir_path="`dirname "$_filter_path"`"
    if [ ! -d "$_filter_dir_path" ]; then
        mkdir -p -m 0640 "$_filter_dir_path"
    fi
    create_filter_list > "$_filter_path"
    exit 0
fi

# display a new line, to distinguish between multiple executions
# (i.e.: with multiple device to decrypt)
echo >&2

# key is specified (either by env var or argument)
if [ "$CRYPTTAB_KEY" = '' -a "$1" != '' ]; then
    CRYPTTAB_KEY="$1"
fi
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

# key is not specified
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
    warning "'keyctl' binary not found"
    warning "On Debian you can install it with: > apt install keyutils"
    KERNEL_CACHE_ENABLED=$FALSE
    warning "Key caching is disabled"
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
    debug "Key ID '$_key_id'"
    _k_id="`keyctl search @u user "$_key_id" 2>/dev/null||true`"
    if [ "$_k_id" != '' ]; then

        # use it
        debug "Using cached key '$_key_id' ($_k_id)"
        info "Unlocking '$crypttarget' with cached key '$_k_id' ..."
        keyctl pipe "$_k_id"
        exit 0
    fi
fi

# check for 'jmtpfs' binary existence
if ! which jmtpfs >/dev/null; then
    error "'jmtpfs' binary not found"
    error "On Debian you can install it with: > apt install jmtpfs"
    exit 2
fi

# ensure usb_common and fuse modules are runing
for _module in usb_common fuse; do
    if [ "`modprobe -nv $_module 2>&1||true`" != '' ]; then
        debug "Loading kernel module '$_module'"
    fi
    modprobe -q $_module
done

# setup flag file to skip devices
if ! touch "$_FLAG_MTP_DEVICES_TO_SKIP"; then
    warning "Failed to create file '$_FLAG_MTP_DEVICES_TO_SKIP'"
fi

# wait for an MTP device to be available
if [ ! -e "$_FLAG_WAITED_FOR_DEVICE_ALREADY" ]; then
    sleep $MTP_SLEEP_SEC_BEFORE_WAIT >/dev/null
    _device_availables="`mtp_device_availables||true`"
    if [ "$_device_availables" = '' ]; then
        info "Waiting for an MTP device to become available (max ${MTP_WAIT_MAX}s) ..."
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
        warning "No MTP device available (after ${MTP_WAIT_MAX}s timeout)"
    fi
    touch "$_FLAG_WAITED_FOR_DEVICE_ALREADY"
else
    debug "Not waiting for MTP device (already done once)"
fi

# create a file in order to catch the result of the subshell
_result_file="`mktemp`"

# for every MTP device
{ cat "$_MTP_DEVICE_LIST_OUT" | while read _line; do
    debug "Device line: '$_line'"

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
        debug "Skipping device '${_vendor_name}, ${_product_name}' (listed as skipped already)"
        continue
    fi

    # mount the device
    if ! mount_mtp_device "$_mount_path" "${_bus_num},${_device_num}" "${_vendor_name}, ${_product_name}"; then
        debug "Skipping device '${_vendor_name}, ${_product_name}' (mount failure)"
        continue
    fi

    # no access to the device's filesystem
    if ! ls -alh "$_mount_path" >/dev/null 2>&1; then
        debug "Device's filesystem is not accessible"

        # assuming the device is locked (and need user manual unlocking)
        # so ask the user to do so, and wait for its input to continue or skip
        info "Please unlock the device '${_vendor_name}, ${_product_name}', then hit enter ... ('s' to skip)"
        read unlocked >/dev/null <&3

        # skip unlocking (give up)
        if [ "$unlocked" = 's' -o "$unlocked" = 'S' ]; then
            info "Skipping unlocking device '${_vendor_name}, ${_product_name}'"

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
        warning "Filesystem of device '${_vendor_name}, ${_product_name}' is not accessible"
        warning "Skipping device '${_vendor_name}, ${_product_name}' (filesystem unaccessible)"
        echo "$_device_unique_id" >> "$_FLAG_MTP_DEVICES_TO_SKIP"
        unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"
        continue
    fi

    # try to get the key file
    _keyfile_path="$_mount_path"/"$CRYPTTAB_KEY"
    if [ ! -e "$_keyfile_path" ]; then
        debug "Keyfile '$_keyfile_path' not found"
        _keyfile_path="`realpath "$_mount_path"/*/"$CRYPTTAB_KEY" 2>/dev/null||true`"
    fi

    # key file found
    if [ "$_keyfile_path" != '' -a -e "$_keyfile_path" ]; then
        debug "Found cryptkey at '$_keyfile_path'"
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
            debug "Device mapper name is: '$_device_mapper_name'"

            # ask for passphrase
            _key_decrypted=$FALSE
            debug "Key is passphrase protected, so trying to decrypt it by asking the user"
            if ! cryptsetup open --readonly "$_keyfile_path" "$_device_mapper_name" >/dev/null <&3; then
                error "Failed to decrypt key '`basename "$_keyfile_path"`' with cryptsetup"
            elif [ ! -e "/dev/mapper/$_device_mapper_name" ]; then
                error "Key decrypted but device mapper '/dev/mapper/$_device_mapper_name' doesn't exists! Bug?"
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
                warning "Failed to add key '$_key_id' to kernel cache"

                # it might be because the data content exceeds the cache max size
                _key_content_size="`du -sk "$_keyfile_to_use"|awk '{print $1}'||true`"
                if [ "$_key_content_size" != '' -a "$_key_content_size" -ge "$KERNEL_CACHE_MAX_SIZE_KB" ]; then
                    warning "Key content size '$_key_content_size' exceeds cache max size of '$KERNEL_CACHE_MAX_SIZE_KB'"
                    warning "The content for key '$_key_id' cannot be cached"
                elif [ "$_key_content_size" != '' ]; then
                    error "Uh, I do not understand the cause of failure (bug?), sorry"
                else
                    error "Failed to get file size of '$_keyfile_to_use'"
                fi
            fi

            # key successfully cached
            if [ "$_k_id" != '' ]; then

                # set timeout (or remove the key in case of failure)
                if ! keyctl timeout "$_k_id" "$KERNEL_CACHE_TIMEOUT_SEC"; then
                    error "Failed to set timeout on cached key '$_k_id'"
                    error "Removing key '$_k_id' from cache"
                    keyctl unlink "$_k_id" @u
                else
                    debug "Cached key at ID '$_k_id'"
                fi
            else
                error "Failed to add key '$_key_id' to kernel cache"
            fi
        fi

        # use the key file
        use_keyfile "$_keyfile_to_use"
        echo "$TRUE" > "$_result_file"

        # passphrase protected and key file is a device mapped
        if [ "$_PASSPHRASE_PROTECTED" = "$TRUE" ] && echo "$_keyfile_to_use"|grep -q '^/dev/mapper/'; then

            # close the device mapper
            debug "Closing the device mapper '$_keyfile_to_use'"
            cryptsetup close "$_keyfile_to_use"
        fi

        # umount the device
        unmount_mtp_device "$_mount_path"  "${_vendor_name}, ${_product_name}"

        # stop process
        exit 0

    elif [ "$_keyfile_path" != '' ]; then
        debug "Keyfile '$_keyfile_path' not found"
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
