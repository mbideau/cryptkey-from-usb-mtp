# cryptkey-from-usb-mtp: :iphone: > :closed_lock_with_key: > :computer: > :tada: > :rainbow:

Have a good protection against computer thief (physical) by encrypting your hard
drive and using your smartphone to unlock it.  
It is a [Two-factor authentication (2FA)](https://en.wikipedia.org/wiki/Multi-factor_authentication)
providing increased security without pain (password less) or extra cost (no USB
key required).

This shell script reads a key file from a USB 
[MTP](https://en.wikipedia.org/wiki/Media_Transfer_Protocol) device (with
fallback to _askpass_), meant for unlocking encrypted hard drive with
*[cryptsetup](https://wiki.debian.org/CryptsetupDebug)* and
_[crypttab](https://manpages.debian.org/stable/cryptsetup/crypttab.5.en.html)_
in *[initramfs](https://wiki.debian.org/initramfs)*.

*Note: USB MTP devices are usually _Android_ smartphones. To know more about the
_Media Transfer Protocol_ see its
[Wikipedia page](https://en.wikipedia.org/wiki/Media_Transfer_Protocol).*

This shell script supports:  

* mounting USB MTP devices with **jmtpfs**
* caching keys found with **keyctl**
* using an alternative "backup" keyfile
* falling back to **askpass**
* filtering MTP devices by whitelist/blacklist
* using a passphrase protected key (decrypted with **cryptsetup**)
* specifying key path in */etc/crypttab* or a mapping file


## Using your smartphone as a keyfile medium is a good security compromise

On the plus side:

:small_blue_diamond: **Possession factor**: you already have it with you, all
the time (I'm sure :yum:), no need for an extra USB key  
:small_blue_diamond: **Knowledge factor**: the smartphone is locked by a PIN
code or a drawing (if it is a modern one) or you can use an encrypted keyfile 

On the down side:

:small_orange_diamond: a smartphone is an active connected device which might
be hacked remotely, by an evil application, or the proprietary OS  
:small_orange_diamond: to use this feature you need to let the `/boot` partition
unencrypted (like most _grub_ advanced features)  

To lower the aspect of the two downside mentionned above:

:small_orange_diamond: If your smartphone is already hacked, you're screwed
anyway :shit:  
:small_orange_diamond: If someone with expert hacking skills (i.e.: tweaking an
initramfs) have a physical access to your computer, you're also screwed!  

An evil hacker :trollface: needs to know the following in order to perform a
successfull decrypting of your hard disk without your help:

:black_small_square: your partitions are encrypted  
:black_small_square: you use this special script to unlock it with your phone  
:black_small_square: the PIN code of the phone to access the file and
**stealing your phone** (or hacking it)  
:black_small_square: which file is the keyfile in the phone filesystem (you
should use a file looking like noting fancy/obvious)  
:black_small_square: eventually the vendor ID and product ID to mimic your phone
with another USB device (if you have enabled the whitelist filter security)  

So, in case of a stolen computer it is a very good/acceptable solution
:closed_lock_with_key:, otherwise (physical access by geeks) not so much.


## Requirements

If you want to use USB MTP device (that's the whole point) you will need the
**jmtpfs** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install jmtpfs
```

If you want to have key caching, to prevent multiple mounting/unmounting of the
USB MTP device, you will need **keyctl** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install keyutils
```

## Installation


:information_source: *Note: This installation process is for Debian/Ubuntu Linux distribution. It should not be hard to adapt it for other Linux distro: contributions welcome!*


### Get the code (clone this repo) and install script to */sbin*

Clone this repository somewhere ~~over the rainbow~~ in your filesystem  
```sh
~> git clone -q https://github.com/mbideau/cryptkey-from-usb-mtp.git /tmp/cryptkey-from-usb-mtp
```

Copy the file `cryptkey-from-usb-mtp.sh` to your `/sbin` directory and
ensure it has the _execute_ permission flag set  
```sh
~> sudo cp /tmp/cryptkey-from-usb-mtp/cryptkey-from-usb-mtp.sh /sbin/cryptkey-from-usb-mtp
sudo chmod +x /sbin/cryptkey-from-usb-mtp
```

### Have an encrypted disk that need decryption at boot time (initram)

You should already have an encrypted disk/partition with LUKS, let's say we
choose `/dev/vda1`  
```sh
# should not print anything
~> cryptsetup isLuks /dev/vda1||echo 'Not a LUKS device'
```

### Tell *cryptroot* to use this script to get the decrypt key (from USB)

Adjust the `/etc/crypttab` entries accordingly (See
[documentation](https://manpages.debian.org/stable/cryptsetup/crypttab.5.en.html))  
```conf
vda1_crypt  UUID=5163bc36  none  luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs
```  
*Replace 'vda1_crypt' with the device mapper name you want (same as your
encrypted drive plus suffix '_crypt' is common).*  
*We do not specify a key path in third column because we will use a mapping
file (to keep a readable file, and prevent 'systemd' complaining at boot time
about unkown key path), but we could have done that (see below).*

### Tell the script which key to use to decrypt which device

#### Create a keyfile to decrypt the device (if not already done)

Create or choose a file to be your key file  
```sh
~> dd if=/dev/urandom of=/mnt/mtp-device/secret_key.bin bs=1KiB count=31
```  
*Replace '/mnt/mtp-device/secret_key.bin' with the path to the key file in your
mounted USB MTP device's filesystem.*  
:warning: **Note: if you want to be able to use the caching mecanism, you must
use a key file which size is less than 32KiB.**

And add it to your luks devices  
```sh
~> sudo cryptsetup luksAddKey /dev/vda1 /mnt/mtp-device/secret_key.bin
```  
*Replace '/dev/vda1' with your encrypted drive and
'/mnt/mtp-device/secret_key.bin' with your key file path (as above).*  

To use an encrypted key instead of a regular file, create it with:  
```sh
# container file
~> dd if=/dev/urandom of=/mnt/mtp-device/secret_key.enc bs=1KiB count=1059
# encrypt the file
~> cryptsetup luksformat --align-payload 1 /mnt/mtp-device/secret_key.enc
# open it
~> sudo cryptsetup open /mnt/mtp-device/secret_key.enc secret_key_decrypted
# add it to your luks devices
~> sudo cryptsetup luksAddKey /dev/vda1 /dev/mapper/secret_key_decrypted
# close it
~> sudo cryptsetup close secret_key_decrypted
```  
*Replace '/mnt/mtp-device/secret_key.enc' with the path to the key file in your
mounted USB MTP device's filesystem.*  
*Replace '/dev/vda1' with your encrypted drive and '/mnt/mtp-device/secret_key.enc'
with your key file path (as above).*  
:warning: **Note: if you want to be able to use the caching mecanism, you must use a key
file which size is less than 1059KiB (LUKS header included).**  

#### Add the mapping between device and key

Execute the following command:  
```sh
~> cryptkey-from-usb-mtp --add-mapping vda1_crypt "Mémoire interne de stockage/Mon fichier très secret.bin"
```  

This will add the following line in mapping file
`/etc/cryptkey-from-usb-mtp/mapping.conf`:  
```conf
vda1_crypt | urlenc | M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin
```  

For an encrypted key file add `encrypted` as last argument, like:
```sh
~> cryptkey-from-usb-mtp --add-mapping vda1_crypt "Mémoire interne de stockage/Mon fichier très secret.bin" encrypted
```  

Which will add the following line in mapping file
`/etc/cryptkey-from-usb-mtp/mapping.conf`:  
```conf
vda1_crypt | pass,urlenc | M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin
```  
*Note: the 'pass' in the second column means 'encrypted'. We use the keyword 'pass' to distinguish from 'urlenc'.*

### Tell *update-initramfs* to include required files

Install the initramfs hook  
```sh
~> cryptkey-from-usb-mtp --initramfs-hook
```

Update the initramfs  
```sh
~> update-initramfs -tuck all
```

Check that everything has been copied inside initramfs  
```sh
~> cryptkey-from-usb-mtp --check-initramfs
```

### Reboot

Pray hard! :pray:  
```sh
~> reboot
```

### Congrats! Support me/us/this!

You are now more secured and without too much pain!  
Great improvment! :tada: :thumbsup:

**Say thank you** :heartbeat: :blush:  
:star: star the repo on Github  
:love_letter: email me  
:loudspeaker: write about it on your blog/social media

**Contribute back** by:

* helping other users
* adapting the script to other Linux flavors
* translating its messages to other langages
* helping to include it into distro packages
* see the [TODO list](#TODO) (below)

## Tests

This has been extensively tested on my desktop machine with _Debian stretch
(9.5)_ over a kernel _Linux 4.9.0.7-amd64_
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
                             '/etc/initramfs-tools/hooks/cryptkey-from-usb-mtp'.

  --check-initramfs [PATH] Check that every requirements had been copied
                           inside the initramfs specified.
                           PATH is optional. It defaults to:
                             '/boot/initrd.img-4.9.0-8-amd64'.

  --create-filter [PATH]   Create a filter list based on current available
                           devices (i.e.:produced by 'jmtpfs -l').
                           PATH is optional. It defaults to:
                             '/etc/cryptkey-from-usb-mtp/devices.blacklist'.

  --add-mapping DM_TARGET KEY_PATH [encrypted]
                           Add a mapping between a DM target DM_TARGET and a
                           key path KEY_PATH. The key might be encrypted in
                           which case you need to specify it with 'encrypted'.
                           If the key path contains non-ascii char it will be
                           automatically url-encoded and added option 'urlenc'.
                           The mapping entry will be added to file:
                             '/etc/cryptkey-from-usb-mtp/mapping.conf'.

  --check-mapping [PATH]   Check a mapping file.
                           PATH is optional. It defaults to:
                             '/etc/cryptkey-from-usb-mtp/mapping.conf'.

ENV:

  CRYPTTAB_KEY             A path to a key file.
                           The env var is optional if the argument 'keyfile'
                           is specified, required otherwise.
                           Same process apply as for the 'keyfile' argument,
                           i.e.: removing quotes, URL decoding and decrypting.

  crypttarget              The target device mapper name (unlocked).
                           It is used to do the mapping with a key if none is
                           specified in the crypttab file, else informative only.

  cryptsource              (informative only) The disk source to unlock.


FILES:

  /sbin/cryptkey-from-usb-mtp
                           This shell script (to be included in the initramfs)

  /etc/initramfs-tools/hooks/cryptkey-from-usb-mtp
                           The default path to initramfs hook

  /etc/cryptkey-from-usb-mtp/devices.blacklist
                           The path to a list of filtered devices (whitelist/blacklist)

  /etc/cryptkey-from-usb-mtp/mapping.conf
                           The path to a mapping file containing mapping between
                           crypttab DM target entries and key (options and path).


EXAMPLES:

  # encoding a string to further add it to /etc/crypttab
  > cryptkey-from-usb-mtp --encode 'relative/path to/key/file/on/usb/mtp/device'

  # decode a URL encoded string, just to test
  > cryptkey-from-usb-mtp --decode 'relative/path%20to/key/file/on/usb/mtp/device'

  # used as a standalone shell command to unlock a disk
  > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 \
    /sbin/cryptkey-from-usb-mtp 'urlenc:M%c3%a9moire%20interne%2fkey.bin'    \
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt

  # a /etc/crypttab entry configuration URL encoded to prevent crashing on spaces and UTF8 chars
  md0_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs

  # a /etc/crypttab entry configuration URL encoded and passphrase protected
  md0_crypt  UUID=5163bc36 'urlenc:pass:M%c3%a9moire%20interne%2fkeyfile.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs

  # a /etc/crypttab entry configuration without any key (key will be specified in a mapping file)
  md0_crypt  UUID=5163bc36   none  luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs

  # add the mapping between DM target 'md0_crypt' and a key (encrypted)
  > cryptkey-from-usb-mtp --add-mapping md0_crypt "Mémoire interne/keyfile.bin" encrypted

  # the command above will result in the following mapping entry in /etc/cryptkey-from-usb-mtp/mapping.conf
  md0_crypt | urlenc,pass | M%c3%a9moire%20interne%2fkeyfile.bin

  # check the mapping file syntax
  > cryptkey-from-usb-mtp --check-mapping

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

### Hide your key path to non-root users

Prevent non-root users to see the file used as a key, defined in
`/etc/crypttab`, by making the config file not readable by everyone:  
```sh
~> chmod 640 /etc/crypttab
```

Same with the (optional) mapping file:  
```sh
~> chmod 640 /etc/cryptkey-from-usb-mtp/mapping.conf
```

### Specify the key path (and options) directly inside /etc/crypttab (no mapping file)

If you want to specify the key path directly inside `/etc/crypttab` do the
following.

To prevent messing with spaces and non-ascii chars, you can urlencode the path
to the keyfile with the command:  
```sh
~> cryptkey-from-usb-mtp --encode "Mémoire interne de stockage/Mon fichier très secret.bin"
```
Then adjust the `/etc/crypttab` third entry to use 'urlenc:'  
```conf
vda1_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin' luks,keyscript=/sbin/cryptkey-from-usb-mtp,initramfs
```  
*If your key is encrypted, add 'pass:' before 'urlenc'.*  


## Troubleshooting

### Debuging

If you want more information on what this script is really doing under the
hood, you can enable debuging  
```sh
~> sed 's/^DEBUG=.*/DEBUG=\$TRUE/' -i /sbin/cryptkey-from-usb-mtp
```

I recommend you to also show the filename of the key used to decrypt the
partitions  
```sh
~> sed 's/^DISPLAY_KEY_FILE=.*/DISPLAY_KEY_FILE=\$TRUE/' -i /sbin/cryptkey-from-usb-mtp
```

Then update the initramfs, check it and reboot  
```sh
~> update-initramfs -tuck all && cryptkey-from-usb-mtp --check-initramfs && reboot
```

**Note: instead of editing the shell script directly you might better edit the
hook script to modify included script in initramfs.**

In the file `/etc/initramfs-tools/hook/cryptkey-from-usb-mtp` after the line  
```sh
copy_file 'file' "/sbin/cryptkey-from-usb-mtp"; [ $? -le 1 ] || exit 2
```  
add the following  
```sh
sed -i "$DESTDIR"/sbin/cryptkey-from-usb-mtp \
    -e 's/^DEBUG=.*/DEBUG=\$TRUE/'           \
    -e 's/^DISPLAY_KEY_FILE=.*/DISPLAY_KEY_FILE=\$TRUE/'
```


### Booting from an initramfs shell

If you happen to corrupt your initramfs and your system drop you to an initramfs
shell (_busybox_), you can follow those steps to boot.

Manually decrypt your partitions  
```sh
~> cryptsetup open /dev/vda1 vda1_crypt
```  
*Replace 'vda1' with the name of your patition.*

Mount the root partition (and all others paritions into it)  
```sh
~> mount /dev/mapper/vda1_crypt /root
```  
*Replace 'vda1' with the name of your patition and do not forget to add mount
required options with '-o OPTIONS'.*  
**Note: '/root' is the default root filesystem target directory for Debian
initramfs, but you can use any directory you want.**

Mount system's partitions  
```sh
~> mount --bind /proc    /root/proc
~> mount --bind /sys     /root/sys
~> mount --bind /dev     /root/dev
~> mount --bind /dev/pts /root/dev/pts
```

Then you have 2 options:
1. exit the initramfs shell, and the boot process should continue successfully  
2. chroot into the root filesystem with `chroot /root /bin/bash`

Once logged in (or into) the root filesystem, do your modifications, then
update the initramfs, check it and reboot  
```sh
~> update-initramfs -tuck all && cryptkey-from-usb-mtp --check-initramfs && reboot
```

### TODO

- [ ] add locales like for
[luksFormat](https://salsa.debian.org/cryptsetup-team/cryptsetup/tree/master/debian/scripts/po)
(and do the French translation of luksFormat while at it)
- [ ] build a test suite (using virtualisation to do many runs and check boot
success)
- [ ] contact Debian cryptsetup team to ask to add the script to
[their repo](https://salsa.debian.org/cryptsetup-team/cryptsetup/tree/master/debian/scripts)
- [ ] contact other distro (Arch) to ask for integration (Dracut maybe)
- [ ] start a communication campaign (if the feedbacks are positives enough)


## Author and Date

Michael Bideau, created the 2019-01-18

