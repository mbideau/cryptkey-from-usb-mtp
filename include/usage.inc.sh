#!/bin/sh
#
# This script is meant to be included/sourced from the main script.
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

# display the default environment section of the usage command
usage_environment()
{
    _left_margin="$USAGE_LEFT_MARGIN"
    if [ "$_left_margin" = '' ]; then
        _left_margin='        '
    fi
    cat <<ENDCAT
    DEBUG    
$_left_margin`__tt "Enable the debug mode (verbose output to '%s')." 'STDERR'`

    CONFIG_DIR    
$_left_margin`__tt "Force the path to a configuration directory."`

    INCLUDE_DIR    
$_left_margin`__tt "Force the path to an include directory."`

    LANG    
$_left_margin`__tt "Use this locale to do the translation (i.e.: %s)." 'fr_FR.UTF-8'`

    LANGUAGE    
$_left_margin`__tt "Use this language to do the translation (i.e.: %s)." 'fr'`

    TEXTDOMAINDIR    
$_left_margin`__tt "Use this domain directory to do the translation (i.e.: %s)." '/usr/share/locale'`
ENDCAT
}

# display the end of the usage command
usage_bottom(){
    cat <<ENDCAT
`__tt 'AUTHORS'`
 
    `__tt 'Written by'`: $AUTHOR
 
`__tt 'REPORTING BUGS'`
 
    `__tt 'Report bugs to'`: <$MAILING_ADDRESS>
 
`__tt 'COPYRIGHT'`
 
    `copyright`
    `license|sed "2,$ s/^/    /"`
    `warranty`
 
`__tt 'SEE ALSO'`
 
    `__tt 'Home page'`: <$HOME_PAGE>
 
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
    _current_year="`date '+%Y'`"
    echo "Copyright (C) 2019`if [ "$_current_year" != '2019' ]; then printf '-'; date -R; fi` $AUTHOR."
}

# diplay license
license()
{
    echo "`__tt "License %s: %s <%s>" 'GPLv3+' 'GNU GPL version 3 or later' 'https://gnu.org/licenses/gpl.html'`"
    echo "`__tt "This is free software: you are free to change and redistribute it."`"
}

# diplay warranty
warranty()
{
    echo "`__tt "There is NO WARRANTY, to the extent permitted by law."`"
}

