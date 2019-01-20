# cryptkey-from-usb-mtp

Have a good protection againt computer thief (physical) by encrypting your hard drive and using your smartphone to unlock it.
It is a [Two-factor authentication (2FA)](https://en.wikipedia.org/wiki/Multi-factor_authentication) providing increased security without pain (password less) or extra cost (no more USB key).

This script reads a key file from a USB [MTP](https://en.wikipedia.org/wiki/Media_Transfer_Protocol) device (with fallback to _askpass_), meant for unlocking encrypted hard drive with *[cryptsetup](https://wiki.debian.org/CryptsetupDebug)* and _[crypttab](https://manpages.debian.org/stable/cryptsetup/crypttab.5.en.html)_ in *[initramfs](https://wiki.debian.org/initramfs)*.

USB MTP devices are usually _Android_ smartphones. To know more about the _Media Transfer Protocol_ see its [Wikipedia page](https://en.wikipedia.org/wiki/Media_Transfer_Protocol)*).


## Using your smartphone as a keyfile medium is a good security compromise

On the plus side:

* **Possession factor**: you already have it with you, all the time (I'm sure :-P), no need for an extra USB key
* **Knowledge factor**: the smartphone is locked by a PIN code or a drawing (if it is a modern one)

On the down side:

- a smartphone is an active connected device which might be hacked remotely, by an evil application, or the proprietary OS
- to use this feature you need to let the `/boot` partition unencrypted (like most _grub_ advanced features)

To lower the risk of the two downside mentionned above:

- If your smartphone is already hacked, you're screwed anyway :-P
- If someone with expert hacking skills (i.e.: tweaking an initramfs) have a physical access to your computer, you're also screwed!

An evil hacker needs to know the following in order to perform a successfull decrypting of your hard disk without your help:

* your partitions are encrypted
* you use this special script to unlock it with your phone
* the PIN code of the phone to access the file and **stealing your phone** (or hacking it)
* which file is the keyfile in the phone filesystem (you should use a file looking like noting fancy/obvious)
* eventually the vendor ID and product ID to mimic your phone with another USB device (if you have enabled the whitelist filter security)

So, in case of a stolen computer it is a very good/acceptable solution, otherwise (physical access by geeks) not so much.


## Requirements

If you want to use USB MTP device (that's the whole point) you will need the **jmtpfs** binary.
On Debian you can install it with:
```sh
apt install jmtpfs
```

If you want to have key caching, to prevent multiple mounting/unmounting of the USB MTP device, you will need **keyctl** binary.
On Debian you can install it with:
```sh
apt install keyutils
```

## Installation

You should have already an encrypted disk/partition with LUKS, let's say we choose `/dev/vda1`
```sh
# should not print anything
cryptsetup isLuks /dev/vda1||echo 'Not a LUKS device'
```

Clone this repository somewhere ~~over the rainbow~~ in your filesystem
```sh
git clone -q https://github.com/mbideau/cryptkey-from-usb-mtp.git /tmp/cryptkey-from-usb-mtp
```

Copy the file `cryptkey-from-usb-mtp.sh` to your `/sbin` directory and ensure it has the _execute_ permission flag set
```sh
sudo cp /tmp/cryptkey-from-usb-mtp/cryptkey-from-usb-mtp.sh /sbin/cryptkey-from-usb-mtp
sudo chmod +x /sbin/cryptkey-from-usb-mtp
```

Create or choose a file to be your key file
```sh
dd if=/dev/urandom of=/mnt/mtp-device/secret_key.bin bs=1kB count=30
```
*Replace '/mnt/mtp-device/secret_key.bin' with the path to the key file in your mounted USB MTP device's filesystem.*  
**Note: if you want to be able to use the caching mecanism, you must use a key file which size is less than 32kB.**

And add it to your luks devices
```sh
sudo cryptsetup luksAddKey /dev/vda1 /mnt/mtp-device/secret_key.bin
```
*Replace '/dev/vda1' with your encrypted drive and '/mnt/mtp-device/secret_key.bin' with your key file path (as above).*  

Adjust the `/etc/crypttab` entries accordingly (See [documentation](https://manpages.debian.org/stable/cryptsetup/crypttab.5.en.html))
```sh
vda1_crypt  UUID=5163bc36 'secret_key.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs
```
*Replace 'vda1_crypt' with the device mapper name you want (same as your encrypted drive plus suffix '_crypt' is common).*

Install the initramfs hook
```sh
cryptkey-from-usb-mtp --initramfs-hook
```

Update the initramfs
```sh
update-initramfs -tuck all
```

Check that everything has been copied inside initramfs
```sh
cryptkey-from-usb-mtp --check-initramfs
```

Reboot and pray hard! ^^'
```sh
reboot
```

**Say thank you :heartbeat:** (:star: star the repo on Github, :love_letter: email me, :loudspeaker: spread the words) ;-)


## Tests

This has been extensively tested on my desktop machine with _Debian stretch (9.5)_ over a kernel _Linux 4.9.0.7-amd64_
and with an _Android 5.1_ smartphone.
No more, **be warned**.


## Usage / Help

```

Print a key to STDOUT from a key file stored on a USB MTP device.

USAGE: cryptkey-from-usb-mtp  OPTIONS  [keyfile]

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
                             '/etc/initramfs-tools/hooks/cryptkey-from-usb-mtp'.

  --check-initramfs [PATH] Check that every requirements had been copied
                           inside the initramfs specified.
                           PATH is optional. It defaults to:
                             '/boot/initrd.img-4.9.0-8-amd64'.

  --create-filter [PATH]   Create a filter list based on current available
                           devices (i.e.:produced by 'jmtpfs -l').
                           PATH is optional. It defaults to:
                             '/etc/cryptkey-from-usb-mtp/devices.blacklist'.

ENV:

  CRYPTTAB_KEY             A path to a key file.
                           The env var is optional if the argument 'keyfile'
                           is specified, required otherwise.
                           Same process apply as for the 'keyfile' argument,
                           i.e.: removing quotes and URL decoding.

  cryptsource              (informative only) The disk source to unlock.

  crypttarget              (informative only) The target device mapper name unlocked.


FILES:

  /sbin/cryptkey-from-usb-mtp
                           This shell script (to be included in the initramfs)

  /etc/initramfs-tools/hooks/cryptkey-from-usb-mtp
                           The default path to initramfs hook

  /etc/cryptkey-from-usb-mtp/devices.*list
                           The path to a list of filtered devices (whitelist/blacklist).


EXAMPLES:

  # encoding a string to further add it to /etc/crypttab
  > cryptkey-from-usb-mtp --encode 'relative/path to/key/file/on/usb/mtp/device'

  # decode a URL encoded string, just to test
  > cryptkey-from-usb-mtp --decode 'relative/path%20to/key/file/on/usb/mtp/device'

  # used as a standalone shell command to unlock a disk
  > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 \
    /sbin/cryptkey-from-usb-mtp 'urlenc:M%c3%a9moire%20interne%2fkey.bin'    \
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt

  # a crypttab entry configuration URL encoded to prevent crashing on spaces and UTF8 chars
  md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs

  # create an initramfs hook to copy all required files (i.e.: 'jmtpfs') in it
  > cryptkey-from-usb-mtp --initramfs-hook

  # update the content of the initramfs
  > update-initramfs -tuck all

  # check that every requirements had been copied inside initramfs
  > cryptkey-from-usb-mtp --check-initramfs

  # reboot and pray hard! ^^'
  > reboot
  
  # add a whitelist filter based on currently available MTP devices
  > sed 's/^MTP_FILTER_STRATEGY=.*/MTP_FILTER_STRATEGY=whitelist/' -i /sbin/cryptkey-from-usb-mtp
  > cryptkey-from-usb-mtp --create-filter

  # enable debug mode, update initramfs, check it and reboot
  > sed 's/^DEBUG=.*/DEBUG=\0/' -i /sbin/cryptkey-from-usb-mtp
  > update-initramfs -tuck all && cryptkey-from-usb-mtp --check-initramfs && reboot

```

## Tips

Prevent non-root users to see the file used as a key, defined in `/etc/crypttab`, by making the config file not readable by everyone:
```sh
chmod 640 /etc/crypttab
```

## Troubleshooting

### Debuging

If you want more information on what this script is really doing under the hood, you can enable debuging
```sh
sed 's/^DEBUG=.*/DEBUG=\$TRUE/' -i /sbin/cryptkey-from-usb-mtp
```

I recommend you to also show the filename of the key used to decrypt the partitions
```sh
sed 's/^DISPLAY_KEY_FILE=.*/DISPLAY_KEY_FILE=\$TRUE/' -i /sbin/cryptkey-from-usb-mtp
```

Then update the initramfs, check it and reboot
```sh
update-initramfs -tuck all && cryptkey-from-usb-mtp --check-initramfs && reboot
```

**Note: instead of editing the shell script directly you might better edit the hook script to modify included script in initramfs.**

In the file `/etc/initramfs-tools/hook/cryptkey-from-usb-mtp` after the lines
```sh
copy_file 'file' "/sbin/cryptkey-from-usb-mtp"
[ \$? -le 1 ] || exit 2
```
add the following
```sh
sed -i "$DESTDIR"/sbin/cryptkey-from-usb-mtp \
    -e 's/^DEBUG=.*/DEBUG=\$TRUE/'           \
    -e 's/^DISPLAY_KEY_FILE=.*/DISPLAY_KEY_FILE=\$TRUE/'
```


### Booting from an initramfs shell

If you happen to corrupt your initramfs and your system drop you to an initramfs shell (_busybox_), you can follow those steps to boot.

Manually decrypt your partitions
```sh
cryptsetup open /dev/vda1 vda1_crypt
```
*Replace 'vda1' with the name of your patition.*

Mount the root partition (and all others paritions into it)
```sh
mount /dev/mapper/vda1_crypt /root
```
*Replace 'vda1' with the name of your patition and do not forget to add mount required options with '-o OPTIONS'.*
**Note: '/root' is the default root filesystem target directory for Debian initramfs, but you can use any directory you want.**

Mount system's partitions
```sh
mount --rbind /proc    /root/proc
mount --rbind /sys     /root/sys
mount --rbind /dev     /root/dev
mount --rbind /dev/pts /root/dev/pts
```

Then you have 2 options:
1. exit the initramfs shell, and the boot process should continue successfully  
2. chroot into the root filesystem with `chroot /root /bin/bash`

Once in logged in (or into) the root filesystem, do your modifications, then update the initramfs, check it and reboot
```sh
update-initramfs -tuck all && cryptkey-from-usb-mtp --check-initramfs && reboot
```


## Author and Date

Michael Bideau, created the 2019-01-18

