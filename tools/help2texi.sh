#!/bin/sh
#
# Produce a Texinfo formatted help (for man pages)
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

# man
DEFAULT_MAN_SECTION_NUM=1
DEFAULT_MAN_SECTION_NAME='User Commands'

# translation
if [ "$TEXTDOMAIN" = '' ]; then
    TEXTDOMAIN=messages
fi
export TEXTDOMAIN
export TEXTDOMAINDIR
if [ "$LANG" = '' ]; then
    LANG=C.UTF-8
fi
export LANG
export LANGUAGE

# gettext binary
GETTEXT="`which gettext 2>/dev/null||which echo`"

# this script filename and path
_THIS_FILENAME="`basename "$0"`"
_THIS_REALPATH="`realpath "$0"`"

# display usage
usage()
{
    cat <<ENDCAT

$_THIS_FILENAME - Convert a help to Texinfo format. Print its output to STDOUT.

USAGE

    $_THIS_FILENAME OPTIONS... FILE PROG_NAME PACKAGE VERSION  
    $_THIS_FILENAME -h|--help  

ARGUMENTS

    FILE    
            Can be either:
                - path to a file containing the output of the help
                - path to an executable script/binary which will be ran with
                  '--help' to produce a (temp) file used as the source

    PROG_NAME    
            The name of the program which manual is for

    PACKAGE    
            The name of the package containing the program

    VERSION    
            The version of the package

OPTIONS

    --man-section-num NUMBER    
            The man section NUMBER.
            Default to: '$DEFAULT_MAN_SECTION_NUM'.

    --man-section-name STRING    
            Then man section name.
            Default to: '$DEFAULT_MAN_SECTION_NAME'.

ENVIRONMENT

    TEXTDOMAIN    
            The domain to extract translation from (i.e.: messages)

    TEXTDOMAINDIR    
            The path to the domain directory (i.e.: /usr/share/locale)

    LANG    
            The locale to use for the translation (i.e.: fr_FR.UTF-8)

    LANGUAGE    
            The language to use for the translation (i.e.: fr)

EXAMPLES

    # convert an already generated help file to Texinfo format  
    > $_THIS_FILENAME /tmp/help.txt.tmp > /tmp/help.texinfo.tmp
    
    # read the freshly converted file with man  
    > man /tmp/help.texinfo.tmp

    # convert the output of the script to produce a Texinfo file  
    > $_THIS_FILENAME /bin/incredible > /tmp/incredible-help.texinfo.tmp

AUTHORS

    Written by: Michael Bideau [France]

COPYRIGHT

    Copyright (C) 2019 Michael Bideau [France].  
    License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.  
    This is free software: you are free to change and redistribute it.  
    There is NO WARRANTY, to the extent permitted by law.

SEE ALSO

    help2man - A full featured script that share the same goal but does it differently.

ENDCAT
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
# remove spaces at the begining and end of a string
# meant to be used with a piped input
trim()
{
    sed 's/^[[:blank:]]*//g;s/[[:blank:]]*$//g'
}
# translate a text and use printf to replace strings
# $1  string  the string to translate
# $.. string  string to substitute to '%s' (see printf format)
__tt()
{
    _t="`"$GETTEXT" "$1"|tr -d '\n'|trim`"
    shift
    printf "$_t\n" "$@"
}


# display help
if [ "$1" = '' -o "$1" = '-h' -o "$1" = '--help' ]; then
    usage
    exit 0
fi

# default options values
man_section_num=$DEFAULT_MAN_SECTION_NUM
man_section_name=$DEFAULT_MAN_SECTION_NAME

# options
while echo "$1"|grep -q '^--'; do
    if [ "$1" = '--man-section-num' ]; then
        if [ "$2" != '' ] && ! echo "$2"|grep -q '^--'; then
            if ! echo "$2"|grep -q '^[1-8]$'; then
                echo "ERROR: Invalid value for option '--man-section-num' (must be an integer between 1 and 8)" >&2
                exit 2
            fi
            man_section_num="$2"
            shift
        else
            echo "ERROR: option '--man-section-num' require a value" >&2
            exit 2
        fi
    elif [ "$1" = '--man-section-name' ]; then
        if [ "$2" != '' ] && ! echo "$2"|grep -q '^--'; then
            man_section_name="$2"
            shift
        else
            echo "ERROR: option '--man-section-name' require a value" >&2
            exit 2
        fi
    else
        echo "ERROR: Invalid option '$1'" >&2
        exit 2
    fi
    shift
done

# arguments
src="$1"
prog_name="$2"
package="$3"
version="$4"

if [ $# -lt 4 ]; then
   echo "ERROR: Too few arguments" >&2
   usage
   exit 2
fi

for _k in prog_name package version; do
    eval _v="\$$_k"
    if [ "$_v" = '' ]; then
       echo "ERROR: Argument '`echo -n "$_k"|tr '[:lower:]' '[:upper:]'`' is required" >&2
       usage
       exit 1
    fi
done

# file doesn't exist
if [ ! -e "$src" ]; then
    echo "ERROR: file '$src' doesn't exist" >&2
    exit 1
fi

# was given an executable
if [ -x "$src" ]; then
    _tmp="`mktemp`"
    #echo "[DEBUG] Using executable '$src' with argument '--help' redirected to '$_tmp'" >&2
    #echo "[DEBUG] > $src --help >$_tmp" >&2
    "$src" --help >"$_tmp"
    src="$_tmp"
fi

# destination (file)
dest="`mktemp`"

# prepare some translations
_t_files="`__tt 'FILES'`"
_t_usage="`__tt 'USAGE'`"
_t_environment="`__tt 'ENVIRONMENT'`"
_t_synopsis="`__tt 'SYNOPSIS'`"

# modify the content with the following replacements:
#  - remove relative path in FILES section
#  - create sections
#  - add bold font to options
#  - add TP MACRO before line ending with 4 spaces
#  - break line with RE MACRO when ending with two spaces (like Markdown)
#  - fix 'pipe' character in options with bold font
#  - replace the 'USAGE' term by 'SYNOPSIS' (even translated)
#  - escape minus sign (considered as hyphen otherwise), starting from line 3
#  - remove left spaces
#  - replace line that are empty or only spaces with the PP MACRO
sed "$src"                                   \
-e '/^'"$_t_files"'$/,/^[^ ]/ s/^\([[:blank:]]*\)\.\//\1/g' \
-e 's/^\([A-Z0-9]\+[A-Z0-9_ ]*\)$/.SH \1/g'  \
-e 's/\(.*\)    $/.TP\n\1/g'                 \
-e 's/  $/\n.RE/g'                           \
-e '/^\.SH '"$_t_usage"'$/,/^\.SH '"$_t_environment"'$/ s/\(^\| \)\(\[\)\?\(--\?[^] ]\+\)\(\]\)\?/\1\2\\fB\3\\fR\4/g' \
-e 's/\(\\fB[^] ]\+\)|\([^] ]\+\\fR\)/\1\\fR|\\fB\2/g' \
-e 's/^\.SH '"$_section_usage"'$/\.SH '"$_section_synopsis"'/' \
-e '3,$ s/-/\\-/g'                           \
|sed                                         \
-e 's/^[[:blank:]]*\([^ ]\)/\1/g'            \
-e 's/^[[:blank:]]*$/.PP/g'                  \
> "$dest"

# display the tweaked help with header and name section at the top
echo ".TH `echo "$prog_name"|tr '[[:lower:]]' '[[:upper:]]'` \"$man_section_num\" \"`date '+%B %Y'`\" \"$package $VERSION\" \"$man_section_name\""
#echo "@documentlanguage $LANGUAGE"
#echo "@documentencoding UTF-8"
echo ".SH `__tt 'NAME'`"
cat "$dest"

# remove temp files
rm -f "$dest"
if [ "$src" != "$1" ]; then
    rm -f "$src"
fi

# exit cleanly
exit 0

