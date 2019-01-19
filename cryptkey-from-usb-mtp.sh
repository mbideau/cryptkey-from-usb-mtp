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
# 
# Author : Michael Bideau
# Licence: GPL v3.0
#

set -e

# constants
TRUE=0
FALSE=1

# configuration
DEBUG=$FALSE
DISPLAY_KEY_FILE=$FALSE
MOUNT_BASE_DIR=/mnt
CRYPTKEY_DEFAULT_REL_PATH=crypto_keyfile.bin
KEYFILE_BAK=/crypto_keyfile.bin.disabled
MTP_WAIT_TIME=5
MTP_WAIT_MAX=30
KERNEL_CACHE_ENABLED=$TRUE
KERNEL_CACHE_MAX_SIZE_KB=32
KERNEL_CACHE_TIMEOUT_SEC=120
INITRAMFS_HOOK_PATH_DEFAULT=/etc/initramfs-tools/hook/`basename "$0" '.sh'`
INITRAMFS_PATH_DEFAULT=/boot/initrd.img-`uname -r`

# internal constants
_FLAG_WAITED_FOR_DEVICE_ALREADY=/.mtp-waited-already.flag
_MTP_DEVICE_LIST_OUT=/.mtp_device.lst.out
_JMTPFS_ERROR_LOGFILE=/.jmtpfs.err.log
_IFS_BAK="$IFS"
_PRINTF="`which printf`"

# usage
usage()
{
	cat <<ENDCAT

Print a key to STDOUT from a key file stored on a USB MTP device.

USAGE: `basename "$0"` OPTIONS [keyfile]

ARGUMENTS:
  keyfile    optional      Is the path to a key file.
                           The argument is optional if the env var CRYPTTAB_KEY
                           is specified, required otherwise.
                           It is relative to the device mount point/dir.
                           Quotes ['"] will be removed at the begining and end.
                           If it starts with 'urlenc:' it will be URL decoded.
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

ENV:
  CRYPTTAB_KEY             A path to a key file.
                           The env var is optional if the argument 'keyfile'
                           is specified, required otherwise.
                           Same process apply as for the 'keyfile' argument,
                           i.e.: removing quotes and URL decoding.

  cryptsource              (informative only) The disk source to unlock.

  crypttarget              (informative only) The target device mapper name unlocked.


EXAMPLES:
    # encoding a string to further add it to /etc/crypttab
    > `basename "$0"` --encode 'relative/path to/key/file/on/usb/mtp/device'

    # decode a URL encoded string, just to test
    > `basename "$0"` --decode 'relative/path%20to/key/file/on/usb/mtp/device'

    # a crypttab entry configuration URL encoded to prevent crashing on spaces and UTF8 chars
    md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=`realpath "$0"`,initramfs

    # used as a standalone shell command
    > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 "`realpath "$0"`" 'urlenc:M%c3%a9moire%20interne%2fkey.bin'

    # create an initramfs hook to copy all required files (i.e.: 'jmtpfs') in it
    > `basename "$0"` --initramfs-hook

    # update the content of the initramfs
    > update-initramfs -tuck all
    
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
copy_exec /usr/bin/jmtpfs

# jmtpfs fail if there are no magic file directory, so we create it
[ ! -d "\$DESTDIR"/usr/share/misc/magic ] && mkdir -p "\$DESTDIR"/usr/share/misc/magic

# copy the script
copy_file 'file' "`realpath "$0"`"
[ \$? -le 1 ] || exit 2

# copy keyctl binary (optional), for caching keys
[ -x /bin/keyctl ] && copy_exec /bin/keyctl

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
urlencode()
{
	_string="$1"
	_strlen="`echo -n "$_string"|wc -c`"
	_encoded=
	_pos=
	_c=
	_o=

	for _pos in `seq 1 $_strlen`; do
		_c=`echo -n "$_string"|cut -c $_pos`
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
# return 0 (TRUE) if at least on device is available for jmtpfs
mtp_device_is_available()
{
	jmtpfs -l >"$_MTP_DEVICE_LIST_OUT" 2>"$_JMTPFS_ERROR_LOGFILE"
	if [ "$?" -ne $TRUE ]; then
		cat "$_JMTPFS_ERROR_LOGFILE" >&2
	fi
	if [ `wc -l "$_MTP_DEVICE_LIST_OUT"|awk '{print $1}'` -gt 1 ]; then
		return $TRUE
	fi
	return $FALSE
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
	if [ "$DEBUG" = "$TRUE" ]; then
		debug "Hit enter to continue ..."
		read cont >/dev/null
	fi
	cat "$1"
}
# fall back helper, that first try a backup key file then askpass
fallback()
{
	# use backup keyfile (if exists)
	if [ -e "$KEYFILE_BAK" ]; then
		use_keyfile "$KEYFILE_BAK"
		exit 0
	fi

	# fall back to askpass (to manually unlock the device)
	/lib/cryptsetup/askpass "Please manually enter key to unlock disk '$crypttarget'"
	exit 0
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
	echo $2 "Warning: $1" >&2
}
error()
{
	echo $2 "Error: $1" >&2
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

# key is specified (either by env var or argument)
if [ "$CRYPTTAB_KEY" = '' -a "$1" != '' ]; then
	CRYPTTAB_KEY="$1"
fi
if [ "$CRYPTTAB_KEY" != '' ]; then

	# remove quoting
	if echo "$CRYPTTAB_KEY"|grep -q '^["'"'"']\|["'"'"']$'; then
		CRYPTTAB_KEY="`echo "$CRYPTTAB_KEY"|sed 's/^["'"'"']*//g;s/["'"'"']*$//g'`"
	fi

	# decode (if encoded)
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

# display a new line, to distinguish between multiple executions
# (i.e.: with multiple device to decrypt)
echo >&2

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
		if [ "$DEBUG" = "$TRUE" ]; then
			debug "Hit enter to continue ..."
			read cont >/dev/null
		fi
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
	if [ "`modprobe -nv $_module`" != '' ]; then
		debug "Loading kernel module '$_module'"
	fi
	modprobe -q $_module
done

# wait for an MTP device to be available
if [ ! -e "$_FLAG_WAITED_FOR_DEVICE_ALREADY" ]; then
	if ! mtp_device_is_available; then
		info "Waiting for an MTP device to become available (max ${MTP_WAIT_MAX}s) ..."
		for i in `seq $MTP_WAIT_TIME $MTP_WAIT_TIME $MTP_WAIT_MAX`; do
			if mtp_device_is_available; then
				break
			fi
			sleep $MTP_WAIT_TIME >/dev/null
			debug '.' -n
		done
	fi
	if ! mtp_device_is_available; then
		warning "No MTP device available (after ${MTP_WAIT_MAX}s timeout)"
	fi
	touch "$_FLAG_WAITED_FOR_DEVICE_ALREADY"
else
	debug "Not waiting for MTP device (already done once)"
fi

# for every MTP device
IFS="
"
for d in `tail -n +2 "$_MTP_DEVICE_LIST_OUT"`; do
	IFS="$IFS_BAK"
	debug "Device line: '$d'"

	# decompose line data
	_bus_num="`     echo "$d"|awk -F ',' '{print $1}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"
	_device_num="`  echo "$d"|awk -F ',' '{print $2}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"
	_product_id="`  echo "$d"|awk -F ',' '{print $3}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"
	_vendor_id="`   echo "$d"|awk -F ',' '{print $4}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"
	_product_name="`echo "$d"|awk -F ',' '{print $5}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"
	_vendor_name="` echo "$d"|awk -F ',' '{print $6}'|sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'`"

	# get a unique mount path for this device
	_product_name_nospace="`echo "$_product_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g'`"
	_vendor_name_nospace="`echo "$_vendor_name"|sed 's/[^a-zA-Z0-9.+ -]//g;s/[[:blank:]]\+/-/g'`"
	_mount_path="$MOUNT_BASE_DIR"/mtp--${_vendor_name_nospace}--${_product_name_nospace}--${_bus_num}-${_device_num}

	# create a mount point
	if [ ! -d "$_mount_path" ]; then
		debug "Creating mount point '$_mount_path'"
		mkdir -p -m 0700 "$_mount_path" >/dev/null
	fi

	# if the device is not already mounted
	if ! mount|grep -q "jmtpfs.*$_mount_path"; then

		# mount the device
		if ! jmtpfs "$_mount_path" -device=${_bus_num},${_device_num} >/dev/null 2>"$_JMTPFS_ERROR_LOGFILE"; then
			cat "$_JMTPFS_ERROR_LOGFILE" >&2
			error "'jmtpfs' failed to mount device '${_vendor_name}, ${_product_name}', ignoring"
		else
			debug "Mounted device '${_vendor_name}, ${_product_name}'"
		fi

	# already mounted
	else
		debug "Device '${_vendor_name}, ${_product_name}' is already mounted"
	fi

	# check that we can access the filesystem of the device
	while ! ls -alh "$_mount_path" >/dev/null 2>&1; do
		debug "Device's filesystem is not accessible"
		info "Please unlock the device '${_vendor_name}, ${_product_name}', then hit enter ... (or hit 's' to skip)"
		read unlocked >/dev/null
		if [ "$unlocked" = 's' -o "$unlocked" = 'S' ]; then
			break
		fi
	done

	# try to get the key file
	_keyfile_path="$_mount_path"/"$CRYPTTAB_KEY"
	if [ ! -e "$_keyfile_path" ]; then
		debug "Keyfile '$_keyfile_path' not found"
		_keyfile_path="`realpath "$_mount_path"/*/"$CRYPTTAB_KEY" 2>/dev/null||true`"
	fi

	# key file found
	if [ "$_keyfile_path" != '' -a -e "$_keyfile_path" ]; then
		debug "Found cryptkey at '$_keyfile_path'"

		# cache the key
		if [ "$KERNEL_CACHE_ENABLED" = "$TRUE" ]; then
			_k_id="`cat "$_keyfile_path"|keyctl padd user "$_key_id" @u||true`"

			# caching failed
			if [ "$_k_id" = '' ]; then
				warning "Failed to add key '$_key_id' to kernel cache"

				# it might be because the data content exceeds the cache max size
				_key_content_size="`du -sk "$_keyfile_path"|awk '{print $1}'||true`"
				if [ "$_key_content_size" != '' -a "$_key_content_size" -gt "$KERNEL_CACHE_MAX_SIZE_KB" ]; then
					warning "Key content size '$_key_content_size' exceeds cache max size of '$KERNEL_CACHE_MAX_SIZE_KB'"
					warning "The content for key '$_key_id' cannot be cached"
				elif [ "$_key_content_size" != '' ]; then
					error "Uh, I do not understand the cause of failure (bug?), sorry"
				else
					error "Failed to get file size of '$_keyfile_path'"
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
		use_keyfile "$_keyfile_path"

		# umount the device
		debug "Unmounting device '${_vendor_name}, ${_product_name}'"
		umount "$_mount_path"
		rmdir "$_mount_path" >/dev/null||true

		# stop process
		exit 0

	elif [ "$_keyfile_path" != '' ]; then
		debug "Keyfile '$_keyfile_path' not found"
	fi

	# umount the device
	debug "Unmounting device '${_vendor_name}, ${_product_name}'"
	umount "$_mount_path"
	rmdir "$_mount_path" >/dev/null||true

	# next device
	IFS="
"
done
IFS="$IFS_BAK"

# fall back
fallback

# vim: set ft=shell:ts=4:sw=4
