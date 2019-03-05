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
* using a passphrase protected keyfile (decrypted with **cryptsetup**)
* specifying keyfile path in */etc/crypttab* or in a mapping file
* translations


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

### jmtpfs
If you want to use USB MTP device (that's the whole point) you will need the
**jmtpfs** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install jmtpfs
```

### keyutils
If you want to have key caching, to prevent multiple mounting/unmounting of the
USB MTP device, you will need **keyctl** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install keyutils
```

### make
If you want to do the intallation with **make** (not manually), you will need the binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install make
```  
*Note: This is the recommended way until a Debian/Ubuntu package is ready.*

### gettext
If you want to have translation support, you will need **gettext** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install gettext
```

### cryptsetup
You should already have **cryptsetup** installed.  
Else, on Debian/Ubuntu you can install it with:  
```sh
debian> apt install cryptsetup
```

### shellcheck
If you want to check for shell errors and POSIX compatibility, you will need **shellcheck** binary.  
On Debian/Ubuntu you can install it with:  
```sh
debian> apt install shellcheck
```


## Installation

### Debian/Ubuntu specific

:information_source: *Note: This installation process is for Debian/Ubuntu Linux distributions. It should not be hard to adapt it for other Linux distros: contributions welcome!*

What might be specific to Debian/Ubuntu:

- the (optional) locales are installed to `/usr/share/locale/<locale>/LC_MESSAGES/cryptkey-from-usb-mtp.mo` which might be Debian/Ubuntu specific (I don't know)

- the (less optional) helper script `tools/initramfs-hook.sh`, which copy every required file in initramfs, is installed in `/etc/initramfs-tools/hooks/` to be automatically called by the *update-initramfs* binary, and it uses `/usr/share/initramfs-tools/hook-functions`, both provided in Debian/Ubuntu distros

- the installation procedure below add the main script as a *keyscript* inside `/etc/crypttab`, which feature might exists only in Debian/Ubuntu (I don't know)


### Get the source code (clone this repo)

Clone this repository somewhere ~~over the rainbow~~ in your filesystem  
```sh
~> git clone -q https://github.com/mbideau/cryptkey-from-usb-mtp.git /tmp/cryptkey-from-usb-mtp
```

### Install files

Change directory into the freshly cloned repository  
```sh
~> cd /tmp/cryptkey-from-usb-mtp
```

Then execute (as _root_)  
```sh
~> sudo make install
```  
*Note: This will install files in `/usr/local/`. If you want to change the destination, add `prefix=DEST_PATH` like `sudo make install prefix=/usr`.*

The following will be installed:  

- **main script** to  
  ```sh
  $sbindir/cryptkey-from-usb-mtp
  ```
- **includes and tools scripts** to  
  ```sh
  $libdir/cryptkey-from-usb-mtp/include/
  $libdir/cryptkey-from-usb-mtp/tools/
  ```
- **initramfs hook** (symlink) to  
  ```sh
  /etc/initramfs-tools/hooks/cryptkey-from-usb-mtp
  ```
- **configuration** to  
  ```sh
  $sysconfdir/cryptkey-from-usb-mtp/
  ```

:information_source: A debian package will be available soon.


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
vda1_crypt  UUID=5163bc36  none  luks,keyscript=/usr/local/sbin/cryptkey-from-usb-mtp,initramfs
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
~> /usr/lib/cryptkey-from-usb-mtp/tools/mapping.sh --add vda1_crypt "Mémoire interne de stockage/Mon fichier très secret.bin"
```  

This will add the following line in mapping file
`/etc/cryptkey-from-usb-mtp/mapping.conf`:  
```conf
vda1_crypt | urlenc | M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin
```  

For an encrypted key file add `encrypted` as last argument, like:
```sh
~> /usr/lib/cryptkey-from-usb-mtp/tools/mapping.sh --add vda1_crypt "Mémoire interne de stockage/Mon fichier très secret.bin" encrypted
```  

Which will add the following line in mapping file
`/etc/cryptkey-from-usb-mtp/mapping.conf`:  
```conf
vda1_crypt | pass,urlenc | M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin
```  
*Note: the 'pass' in the second column means 'encrypted'. We use the keyword 'pass' to distinguish from 'urlenc'.*

### Rebuild initramfs

Rebuild the initramfs  
```sh
~> update-initramfs -tuck all
```

Check that everything has been copied inside initramfs  
```sh
~> /usr/lib/cryptkey-from-usb-mtp/tools/check_initramfs.sh
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
:love_letter: email [me](mailto:mica.devel@gmail.com)  
:loudspeaker: write about it on your blog/social media

**Contribute back** by:

* helping other users
* adapting the script to other Linux flavors
* translating its messages to other langages
* helping to include it into distro packages
* see the [Contributing](#Contributing) section below

## Tests

This has been extensively tested on my desktop machine with _Debian stretch
(9.5)_ over a kernel _Linux 4.9.0.7-amd64_
and with an _Android 5.1_ smartphone.
No more, **be warned**.


## Usage / Help

```
 
cryptkey-from-usb-mtp - Print a key to STDOUT from a key file stored on a USB MTP device.
  
USAGE
 
    cryptkey-from-usb-mtp [keyfile]  
    cryptkey-from-usb-mtp [-h|--help]  
    cryptkey-from-usb-mtp -v|--version
 
ARGUMENTS
 
    keyfile  (optional)    
            Is the path to a key file.
            The argument is optional if the env var CRYPTTAB_KEY is specified, required otherwise.
            It is relative to the device mount point/dir.
            Quotes ['"] will be removed at the begining and end.
            If it starts with 'urlenc:' it will be URL decoded.
            If it starts with 'pass:' it will be decrypted with 'cryptsetup open' on the file.
            'urlenc:' and 'pass:' can be combined in any order, i.e.: 'urlenc:pass:De%20toute%20beaut%c3%a9.jpg' or 'pass:urlenc:De%20toute%20beaut%c3%a9.jpg'.
 
OPTIONS
 
    -h|--help    
            Display this help.
 
    -v|--version    
            Display the version of this script.
 
ENVIRONMENT
 
    CRYPTTAB_KEY    
            A path to a key file.
            The env var is optional if the argument 'keyfile' is specified, required otherwise.
            Same process apply as for the 'keyfile' argument, i.e.: removing quotes, URL decoding and decrypting.
 
    crypttarget    
            The target device mapper name (unlocked).
            It is used to do the mapping with a key if none is specified in the crypttab file, else informative only.
 
    cryptsource    
            (informative only) The disk source to unlock.
 
    DEBUG    
            Enable the debug mode (verbose output to 'STDERR').

    CONFIG_DIR    
            Force the path to a configuration directory.

    INCLUDE_DIR    
            Force the path to an include directory.

    LANG    
            Use this locale to do the translation (i.e.: fr_FR.UTF-8).

    LANGUAGE    
            Use this language to do the translation (i.e.: fr).

    TEXTDOMAINDIR    
            Use this domain directory to do the translation (i.e.: /usr/share/locale).
 
FILES
 
    Note: Paths may have changed, at installation time, by configuration or environment.
 
    /usr/local/sbin/cryptkey-from-usb-mtp    
            Default path to this shell script (to be included in the initramfs).
 
    /usr/local/etc/cryptkey-from-usb-mtp/default.conf    
            Default path to the default configuration file.
 
    /usr/local/etc/cryptkey-from-usb-mtp/local.conf    
            Default path to the local configuration file (i.e.: overrides default.conf).
 
    /usr/local/etc/cryptkey-from-usb-mtp/mapping.conf    
            Default path to the file containing mapping between crypttab DM target and key file.
 
    /usr/local/etc/cryptkey-from-usb-mtp/devices.whitelist    
            Default path to the list of allowed USB MTP devices.
 
    /usr/local/etc/cryptkey-from-usb-mtp/devices.blacklist
            Default path to the list of denied USB MTP devices.
 
    /usr/local/lib/cryptkey-from-usb-mtp/tools/    
            Default path to the directory containg tool scripts to help managing configuration.
 
    /etc/initramfs-tools/hooks/cryptkey-from-usb-mtp    
            Path to initramfs hook that inject required files into initramfs.
 
EXAMPLES
 
    # Use this script as a standalone shell command to unlock a disk  
    > crypttarget=md0_crypt cryptsource=/dev/disk/by-uuid/5163bc36 \  
         /usr/local/sbin/cryptkey-from-usb-mtp 'urlenc:M%c3%a9moire%20interne%2fkey.bin' \  
    | cryptsetup open /dev/disk/by-uuid/5163bc36 md0_crypt

AUTHORS
 
    Written by: Michael Bideau [France]
 
REPORTING BUGS
 
    Report bugs to: <mica.devel@gmail.com>
 
COPYRIGHT
 
    Copyright (C) 2019 Michael Bideau [France].
    License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
    This is free software: you are free to change and redistribute it.
    There is NO WARRANTY, to the extent permitted by law.
 
SEE ALSO
 
    Home page: <https://github.com/mbideau/cryptkey-from-usb-mtp>
 
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
vda1_crypt  UUID=5163bc36 'urlenc:M%c3%a9moire%20interne%20de%20stockage%2fMon%20fichier%20tr%c3%a8s%20secret.bin' luks,keyscript=/usr/local/sbin/cryptkey-from-usb-mtp,initramfs
```  
*If your key is encrypted, add 'pass:' before 'urlenc'.*  


## Troubleshooting

### Debuging

If you want more information on what this script is really doing under the
hood, you can enable debuging  
```sh
~> echo 'DEBUG=$TRUE' >> /etc/cryptkey-from-usb-mtp/local.conf
```

I recommend you to also show the filename of the key used to decrypt the
partitions  
```sh
~> echo 'DISPLAY_KEY_FILE=$TRUE' >> /etc/cryptkey-from-usb-mtp/local.conf
```

Then rebuild the initramfs, check it and reboot  
```sh
~> update-initramfs -tuck all && /usr/lib/cryptkey-from-usb-mtp/tools/check_initramfs.sh && reboot
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

Then you have 2 options:  

1. Exit the initramfs shell, and the boot process should continue successfully  
2. Chroot into the root filesystem

Before chrooting in the filesystem, you need to mount some system's partitions  
```sh
~> mount --bind /proc    /root/proc
~> mount --bind /sys     /root/sys
~> mount --bind /dev     /root/dev
~> mount --bind /dev/pts /root/dev/pts
```

Then execute the chroot  
```sh
~> chroot /root /bin/bash
```

Once logged in (or into) the root filesystem, do your modifications, then
rebuild the initramfs, check it and reboot  
```sh
~> update-initramfs -tuck all && /usr/lib/cryptkey-from-usb-mtp/tools/check_initramfs.sh && reboot
```

## Contributing

### Translation

#### Fixing/Updating a translation

Edit the file locales/<locale>.po, then run `make all` to generate all file that use this translation, and test your result in the main script and tools scripts.

#### Adding a translation

Edit the `Makefile`, find the line starting with  
```sh
LANGS := fr
```  
And add the locale code (two letters) you want separated with a space.

Then run `make all` to generate an empty locale catalogue `locales/<locale>.po` and all file that use this translation.

Follow the [Fixing/Updating a translation](#Fixing/Updating a translation) process then.

### Creating a Debian package

- [ ] create a Debian [guest account](https://signup.salsa.debian.org/register/guest/) to see if we can have a repository
- [ ] develop the script to build the Debian package (using debmake and debuild), use a branch if no Debian repository is available
- [ ] find a Debian mentor to: include the project into Debian CI, have a peer review, and maybe a maintainer

### Supporting other Linux distributions

- [ ] Arch
- [ ] Redhat / CentOS / Fedora
- [ ] Gentoo
- [X] Debian/Ubuntu

### Develoments

- [ ] build a test suite (maybe in Python)
- [ ] add motd/smartphone pluged in picture
- [ ] add a GUI
- [ ] re-implement it in C or other compiled language
- [ ] add colors support
- [ ] remove the need to define a filter strategy (use both files, with whitelist precedence)
- [ ] replace whitelist/blacklist by allow/deny
- [ ] remove the use of urlenc when key file path is defined in mapping
- [X] add translation support (french locale added)
- [X] make it pass `shellcheck`

### Communication

- [ ] add a tips to a tutorial for moving /boot to an encrypted USB key
- [ ] explain why not patching the grub2 boot stage 1.5 instead (with *GRUB_ENABLE_CRYPTODISK*)
- [ ] reference [Evil Abigail](https://github.com/GDSSecurity/EvilAbigail) blackhat script to steal the passphrase with an unencrypted /boot
- [ ] explain why not just a script to mount USB MTP (without key file support)
- [ ] start a communication campaign (if the feedbacks are positives enough)


## Author and creation date

Michael Bideau, created the 2019-01-18.


## Copyright and License

Copyright (C) 2019 Michael Bideau [France]

This file is part of cryptkey-from-usb-mtp.

cryptkey-from-usb-mtp is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

cryptkey-from-usb-mtp is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with cryptkey-from-usb-mtp.  If not, see <https://www.gnu.org/licenses/>.
