# cryptkey-from-usb-mtp

Read a key file from a USB MTP device (with fallback to askpass), meant for unlocking with cryptsetup and crypttab in initramfs.

USB MTP devices are usally _Android_ smartphones.

So with this script, you will be able unlock your encrypted hard disk at boot with just pluging your phone to the computer (assuming you have copied the secret key to it) ;-)


## Requirements

If you want to use USB MTP device (that's the whole point) you will need the **jmtpfs** binary.
On Debian you can install it with:
```
> apt install jmtpfs
```

If you want to have key caching, to prevent multiple mounting/unmounting of the USB MTP device, you will need **keyctl** binary.
On Debian you can install it with:
```
> apt install keyutils
```

## Installation

Clone this repository somewhere (over the rainbow) in your filesystem
```
git clone -q https://github.com/mbideau/cryptkey-from-usb-mtp.git /tmp/cryptkey-from-usb-mtp
```

Copy the file `cryptkey-from-usb-mtp.sh` to your `/sbin` directory and ensure it has the 'execute' permission flag set
```
> sudo cp /tmp/cryptkey-from-usb-mtp/cryptkey-from-usb-mtp.sh /sbin/cryptkey-from-usb-mtp.sh
> sudo chmod +x /sbin/cryptkey-from-usb-mtp.sh
```

Create or choose a file to be your key file
```
> dd if=/dev/urandom of=/mnt/mtp-device/secret_key.bin bs=1kB count=30
```
_Replace '/mnt/mtp-device/secret_key.bin' with the path to the key file in your mounted USB MTP device's filesystem._
**Note: if you want to be able to use the caching mecanism, you must use a key file which size is less than 32kB.**

And add it to your luks devices
```
> sudo cryptsetup luksAddKey /dev/vda1 /mnt/mtp-device/secret_key.bin
```
_Replace '/dev/vda1' with your encrypted drive and '/mnt/mtp-device/secret_key.bin' with your key file path (as above)._

Adjust the `/etc/crypttab` entries accordingly
```
vda1_crypt  UUID=5163bc36 'secret_key.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp.sh,initramfs
```
_Replace 'vda1_crypt' with the device mapper name you want (same as your encrypted drive plus suffix '_crypt' is common)._

Install the initramfs hook
```
> cryptkey-from-usb-mtp.sh --initramfs-hook
```

Update the initramfs
```
> update-initramfs -tuck all
```

Reboot and pray hard! ^^'
```
> reboot
```

**Say thank you** (star the repo on Github, email me, spread the words) ;-)


## Tests

This has been extensively tested on my desktop machine with _Debian stretch (9.5)_ and a kernel _Linux 4.9.0.7-amd64_.
No more, **be warned**.


## Known bugs / Issues

When a USB MTP device is mounted, the shell script checks if the filesystem is accessible.
If not, it assumes the device is not unlocked (like most Android smartphones), and ask the user to do so (then hit enter) in loop until the filesystem is accessible.
Half of the time, I encouter an issue here because, even when the device is unlocked, the filesystem remains unaccessible.
So my recommendation is to **always unlock the USB MTP device before this script is launched** (and maintain it this way as long as the script has not cached the key or finished its job).


## Usage / Help

```

Print a key to STDOUT from a key file stored on a USB MTP device.

USAGE: cryptkey-from-usb-mtp.sh OPTIONS [keyfile]

ARGUMENTS:
    keyfile    optional    Is the path to a key file.
                           The argument is optional if the env var CRYPTTAB_KEY
                           is specified, required otherwise.
                           It is relative to the device mount point/dir.
                           Quotes ['"] will be removed at the begining and end.
                           If it starts with 'urlenc:' it will be URL decoded.
OPTIONS:
    -h|--help              Display this help.

    --encode STRING        When specified, expext a string as unique argument.
                           The string will be URL encoded and printed.
                           NOTE: Usefull to create a key path without spaces
                           to use into /etc/crypttab at the third column.

    --decode STRING        When specified, expext a string as unique argument.
                           The string will be URL decoded and printed.

    --initramfs-hook PATH  Create an initramfs hook to path.
                           PATH is optional. It defaults to:
                             '/etc/initramfs-tools/hook/cryptkey-from-usb-mtp'.

ENV:
    CRYPTTAB_KEY           A path to a key file.
                           The env var is optional if the argument 'keyfile'
                           is specified, required otherwise.
                           Same process apply as for the 'keyfile' argument,
                           i.e.: removing quotes and URL decoding.

    cryptsource            (informative only) The disk source to unlock.

    crypttarget            (informative only) The target device mapper name unlocked.


EXAMPLES:
    # encoding a string to further add it to /etc/crypttab
    > cryptkey-from-usb-mtp.sh --encode 'relative/path to/key/file/on/usb/mtp/device'

    # decode a URL encoded string, just to test
    > cryptkey-from-usb-mtp.sh --decode 'relative/path%20to/key/file/on/usb/mtp/device'

    # a crypttab entry configuration URL encoded to prevent crashing on spaces and UTF8 chars
    md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp.sh,initramfs

    # used as a standalone shell command
    > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 "/sbin/cryptkey-from-usb-mtp.sh" 'urlenc:M%c3%a9moire%20interne%2fkey.bin'

    # create an initramfs hook to copy all required files (i.e.: 'jmtpfs') in it
    > cryptkey-from-usb-mtp.sh --initramfs-hook

    # update the content of the initramfs
    > update-initramfs -tuck all
    
```

## Author and Date

Michael Bideau, the 2019-01-18

