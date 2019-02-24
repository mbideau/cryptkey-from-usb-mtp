# Makefile for cryptkey-from-usb-mtp
#
# Respect GNU make conventions
#  @see: https://www.gnu.org/software/make/manual/make.html#Makefile-Basics
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

AUTHOR_NAME         := Michael Bideau
EMAIL_SUPPORT       := mica.devel@gmail.com

# use POSIX standard shell and fail at first error
.POSIX:

# which shell to use
SHELL              := /bin/sh

# binaries
GETTEXT            ?= gettext
XGETTEXT           ?= xgettext
MSGFMT             ?= msgfmt
MSGINIT            ?= msginit
MSGMERGE           ?= msgmerge
MSGCAT             ?= msgcat
GZIP               ?= gzip
TAR                ?= tar

# source
#srcdir            ?= $(shell pwd)
srcdir             ?= .
MAIN_SCRIPT        := $(srcdir)/cryptkey-from-usb-mtp.sh
MAIN_SCRIPTNAME    := $(notdir $(MAIN_SCRIPT))
INCLUDE_DIR        := $(srcdir)/include
TOOLS_DIR          := $(srcdir)/tools
HOOK_SCRIPT        := $(TOOLS_DIR)/initramfs-hook.sh
LOCALE_DIR         := $(srcdir)/locale
CONFIG_DIR         := $(srcdir)/etc
CONFIG_DEFAULT     := $(CONFIG_DIR)/default.conf
EXAMPLES_DIR       := $(srcdir)/examples
CONFIGS            := $(CONFIG_DEFAULT)
EXAMPLES           := $(wildcard $(EXAMPLES_DIR)/*)
INCLUDES           := $(wildcard $(INCLUDE_DIR)/*.inc.sh)
TOOLS              := $(wildcard $(TOOLS_DIR)/*.sh)

# temp dir
TMPDIR             ?= $(srcdir)/.tmp

# destination
# @see: https://www.gnu.org/software/make/manual/make.html#Directory-Variables
prefix             ?= /usr/local
exec_prefix        ?= $(prefix)
bindir             ?= $(exec_prefix)/bin
sbindir            ?= $(exec_prefix)/sbin
ifeq ($(strip $(prefix)),)
datarootdir        ?= $(prefix)/usr/share
else
datarootdir        ?= $(prefix)/share
endif
datadir            ?= $(datarootdir)
ifeq ($(strip $(prefix)),/usr)
sysconfdir         ?= /etc
else
sysconfdir         ?= $(prefix)/etc
endif
infodir            ?= $(datarootdir)/info
libdir             ?= $(exec_prefix)/lib
localedir          ?= $(datarootdir)/locale
mandir             ?= $(datarootdir)/man
dirs_var_name      := prefix exec_prefix bindir sbindir datarootdir datadir sysconfdir infodir libdir localedir mandir

# install
INSTALL            ?= install
INSTALL_PROGRAM    ?= $(INSTALL) $(INSTALLFLAGS) --mode 750
INSTALL_DATA       ?= $(INSTALL) $(INSTALLFLAGS) --mode 640
INSTALL_DIRECTORY  ?= $(INSTALL) $(INSTALLFLAGS) --directory --mode 750

# package infos
PACKAGE_NAME       ?= $(basename $(notdir $(MAIN_SCRIPT)))
PACKAGE_VERS       ?= 0.0.1

# helper (to produce man pages from --help)
HELP2TEXI          := $(TOOLS_DIR)/help2texi.sh

# locale specific
MAIL_BUGS_TO       := $(EMAIL_SUPPORT)
TEXTDOMAIN         := $(PACKAGE_NAME)
POT_DIR            := $(TMPDIR)/pot
MERGE_POT_FILE     := $(POT_DIR)/$(TEXTDOMAIN).merged.pot
PO_DIR             := $(LOCALE_DIR)
LOCALE_FILES        = $(LANGS:%=$(PO_DIR)/%.po)
MO_DIR             := $(TMPDIR)/locale
POT_MAIN_SCRIPT    := $(addprefix $(POT_DIR)/, $(addsuffix .pot, \
		      $(basename $(notdir $(MAIN_SCRIPT)))))

# man specific
MAN_DIR            := $(TMPDIR)/man
MAN_SECTION        ?= 8
MAN_FILENAME       := $(PACKAGE_NAME)
MAN_SECT_NAME      ?= System Administration Utilities

# charset and languages
CHARSET            := UTF-8
LANGS              := fr
LANGS_PLUS_EN      := en $(LANGS)

# generated files/dirs
LOCALE_DIRS         = $(LANGS:%=$(MO_DIR)/%/LC_MESSAGES)
MO                  = $(addsuffix /$(TEXTDOMAIN).mo,$(LOCALE_DIRS))
MANS                = $(LANGS_PLUS_EN:%=$(MAN_DIR)/%.texi.gz)
POT_SRC_FILES       = $(MAIN_SCRIPT) $(INCLUDES) $(TOOLS)
POT_DST_FILES       = $(addprefix $(POT_DIR)/, $(addsuffix .pot, \
		      $(basename $(notdir $(POT_SRC_FILES)))))
DIRS                = $(POT_DIR) $(PO_DIR) $(MO_DIR) $(LOCALE_DIRS) $(MAN_DIR)

# destinations files/dirs
INST_MAIN_SCRIPT   ?= $(DESTDIR)$(sbindir)/$(basename $(notdir $(MAIN_SCRIPT)))
INST_CONFIG_DIR    ?= $(DESTDIR)$(sysconfdir)/$(PACKAGE_NAME)
INST_CONFIGS       := $(addprefix $(INST_CONFIG_DIR)/,$(notdir $(CONFIGS)))
INST_CONFIG_DEFAULT:= $(INST_CONFIG_DIR)/$(notdir $(CONFIG_DEFAULT))
INST_LIB_DIR       ?= $(DESTDIR)$(libdir)/$(PACKAGE_NAME)
INST_INCLUDE_DIR   ?= $(INST_LIB_DIR)/include
INST_INCLUDES      := $(addprefix $(INST_INCLUDE_DIR)/,$(notdir $(INCLUDES)))
INST_TOOLS_DIR     ?= $(INST_LIB_DIR)/tools
INST_TOOLS         := $(addprefix $(INST_TOOLS_DIR)/,$(notdir $(TOOLS)))
INST_HOOKS_DIR     ?= $(DESTDIR)/etc/initramfs-tools/hooks
INST_HOOK          := $(INST_HOOKS_DIR)/$(PACKAGE_NAME)
INST_LOCALES        = $(LANGS:%=$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(TEXTDOMAIN).mo)
INST_MANS           = $(LANGS_PLUS_EN:%=$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PACKAGE_NAME).$(MAN_SECTION).gz)
INST_EXAMPLES      := $(addprefix $(INST_CONFIG_DIR)/,$(notdir $(EXAMPLES)))
INST_FILES          = $(INST_MAIN_SCRIPT) \
		      $(INST_CONFIGS) $(INST_INCLUDES) $(INST_TOOLS) $(INST_HOOK) \
		      $(INST_LOCALES) $(INST_MANS) \
		      $(INST_EXAMPLES)
#INST_DIRS          = $(dir $(INST_FILES)) # fail because of duplicate prerequisiste entries
INST_DIRS           = $(dir $(INST_MAIN_SCRIPT)) \
		      $(INST_CONFIG_DIR) $(INST_INCLUDE_DIR) $(INST_TOOLS_DIR) $(INST_HOOKS_DIR) \
                      $(dir $(INST_LOCALES)) $(dir $(INST_MANS))

# distribution
DIST_DIR           := $(TMPDIR)/dist
DIST_DIRNAME       ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DIST_DIRPATH       := $(DIST_DIR)/$(DIST_DIRNAME)
DIST_SRC_FILES      = $(MAIN_SCRIPT) $(CONFIGS) $(INCLUDES) $(TOOLS) $(LOCALE_FILES) $(EXAMPLES) \
                      $(srcdir)/README.md $(srcdir)/LICENSE $(srcdir)/Makefile
#DIST_DIRS         := $(addprefix $(DIST_DIRPATH)/,$(dir $(DIST_SRC_FILES))) # fail because of duplicate prerequisiste entries
DIST_FILES          = $(subst $(srcdir)/,$(DIST_DIRPATH)/,$(DIST_SRC_FILES))
DIST_DIRS           = $(subst $(srcdir)/,$(DIST_DIRPATH)/,$(dir $(MAIN_SCRIPT)) \
		      $(CONFIG_DIR) $(INCLUDE_DIR) $(TOOLS_DIR) $(HOOKS_DIR) \
		      $(LOCALE_DIR) $(EXAMPLES_DIR))
DIST_TARNAME       ?= $(DIST_DIRNAME).tar.gz
DIST_TARPATH       := $(DIST_DIR)/$(DIST_TARNAME)
DIST_TARFLAGS      := --create --auto-compress --posix --mode=0755 --recursion \
                      --file "$(DIST_TARPATH)"  \
                      --directory "$(DIST_DIR)" \
                      "$(DIST_DIRNAME)"

# Debian packaging
DEBEMAIL           ?= $(EMAIL_SUPPORT)
DEBFULLNAME        ?= $(AUTHOR_NAME)
DEB_DIR            := $(TMPDIR)/deb
DEB_NAME           ?= $(PACKAGE_NAME)-$(PACKAGE_VERS)
DEB_FILENAME       := $(PACKAGE_NAME)-$(PACKAGE_VERS).deb
DEB_DIRPATH        := $(DEB_DIR)/$(DEB_FILENAME)
DEB_DATA           := $(DEB_DIR)/$(DEB_FILENAME)/data

# msginit and msgmerge use the WIDTH to break lines
WIDTH              ?= 80

# binaries flags
GETTEXTFLAGS       ?=
GETTEXTFLAGS_ALL   := -d "$(TEXTDOMAIN)"
XGETTEXTFLAGS      ?= 
XGETTEXTFLAGS_ALL  := --keyword --keyword=__tt \
		      --language=shell --from-code=$(CHARSET) \
		      --width=$(WIDTH)       \
		      --sort-output          \
		      --foreign-user         \
		      --package-name="$(PACKAGE_NAME)" --package-version="$(PACKAGE_VERS)" \
		      --msgid-bugs-address="$(MAIL_BUGS_TO)"
MSGFMTFLAGS        ?=
MSGFMTFLAGS_ALL    := --check --check-compatibility 
MSGINITFLAGS       ?=
MSGINITFLAGS_ALL   := --no-translator  --width=$(WIDTH)
MSGMERGEFLAGS      ?=
MSGMERGEFLAGS_ALL  := --quiet
MGSCATFLAGS        ?=
MGSCATFLAGS_ALL    := --sort-output --width=$(WIDTH) 
GZIPFLAGS          ?=
TARFLAGS           ?= --gzip

# tools flags
HELP2TEXIFLAGS     ?=
HELP2TEXIFLAGS_ALL := --man-section-num $(MAN_SECTION)
HELP2TEXIARGS_ALL  := $(MAIN_SCRIPT) $(MAIN_SCRIPTNAME) $(PACKAGE_NAME) $(PACKAGE_VERS)


# Use theses suffixes in rules
.SUFFIXES: .po .mo .pot .gz .sh .inc.sh .inc.pot

# Do not delete those files even if they are intermediaries to other targets
.PRECIOUS: $(MO_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo


# replace a variable inside a file (inplace) if not empty (except for PREFIX)
# $(1) string  the name of the variable to replace (will be uppercased)
# $(2) string  the value of the variable to set
# $(3) string  the path to the file to modify
define replace_var_in_file
	name_upper="`echo "$(1)"|tr '[:lower:]' '[:upper:]'`"; \
	if grep -q "^[[:space:]]*$$name_upper=" "$(3)"; then \
		if [ "$(2)" != '' -o "$$name_upper" = 'PREFIX' ]; then \
			echo "## Replacing var '$$name_upper' with value '$(2)' in file '$(3)'"; \
			sed -e "s#^\([[:blank:]]*$$name_upper=\).*#\1"'"'"$(2)"'"'"#g" -i "$(3)"; \
		fi; \
	fi;
endef

# create man page from help of the main script with translation support
# $(1) string the locale
# $(2) string the path to man file output
define generate_man_from_mainscript_help
	if [ ! -e "$(2)" ]; then \
		echo "## Creating man page '$(2)' [$(1)]"; \
	else \
		echo "## Updating man page '$(2)' [$(1)]"; \
	fi; \
	export LANGUAGE=$(1);            \
	export TEXTDOMAINDIR=$(MO_DIR);  \
	export TEXTDOMAIN=$(TEXTDOMAIN); \
	_man_section_name="`$(GETTEXT) $(GETTEXTFLAGS) $(GETTEXTFLAGS_ALL) "$(MAN_SECT_NAME)"`"; \
	PREFIX=$(srcdir) CONFIG_DIR=$(CONFIG_DIR) INCLUDE_DIR=$(INCLUDE_DIR) \
	$(HELP2TEXI)                                        \
		$(HELP2TEXIFLAGS) $(HELP2TEXIFLAGS_ALL)     \
		--man-section-name "$$_man_section_name"    \
		$(HELP2TEXIARGS_ALL)                        \
	|$(GZIP) $(GZIPFLAGS) > "$(2)";
endef


# special case for english manual that do not depends on any translation
# but on main tools and its default configuration
$(MAN_DIR)/en.texi.gz: $(MAIN_SCRIPT) $(CONFIG_DEFAULT)
	@$(call generate_man_from_mainscript_help,en,$@)


# manuals depends on translations
$(MAN_DIR)/%.texi.gz: $(MO_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo $(MAIN_SCRIPT) $(CONFIG_DEFAULT)
	@$(call generate_man_from_mainscript_help,$*,$@)


# compiled translations depends on their not-compiled sources
$(MO_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo: $(PO_DIR)/%.po
	@echo "## Compiling catalogue '$<' to '$@'"
	@$(MSGFMT) $(MSGFMTFLAGS) $(MSGFMTFLAGS_ALL) --output "$@" "$<"


# translations files depends on the main translation catalogue
%.po: $(MERGE_POT_FILE)
	@_lang="`basename "$@" '.po'`"; \
	if [ ! -e "$@" ]; then \
		_lang_U="`echo "$$_lang"|tr '[[:lower:]]' '[[:upper:]]'`"; \
		echo "## Initializing catalogue '$@' from '$<' [$${_lang}_$${_lang_U}.$(CHARSET)]"; \
		$(MSGINIT) $(MSGINITFLAGS) $(MSGINITFLAGS_ALL) --input "$<" --output "$@" \
		           --locale="$${_lang}_$${_lang_U}.$(CHARSET)" >/dev/null; \
	else \
		echo "## Updating catalogue '$@' from '$(MERGE_POT_FILE)' [$${_lang}]"; \
		$(MSGMERGE) $(MSGMERGEFLAGS) $(MSGMERGEFLAGS_ALL) --lang=$$_lang --update "$@" "$<"; \
		touch "$@"; \
	fi;


# main translation catalogue depends on individual catalogue files
$(MERGE_POT_FILE): $(POT_DST_FILES)
	@echo "## merging all pot files into '$@'"
	@$(MSGCAT) $(MGSCATFLAGS) $(MGSCATFLAGS_ALL) --output "$@" $^


# main tools translation catalogue depends on main tools source file
# and its default configuration
$(POT_MAIN_SCRIPT): $(MAIN_SCRIPT)
	@echo "## (re-)generating '$@' from '$<' ..."
	@$(XGETTEXT) $(XGETTEXTFLAGS) $(XGETTEXTFLAGS_ALL) --output "$@" "$<"


# includes translation catalogues depends on their source file
$(POT_DIR)/%.inc.pot: $(INCLUDE_DIR)/%.inc.sh
	@echo "## (re-)generating '$@' from '$<' ..."
	@$(XGETTEXT) $(XGETTEXTFLAGS) $(XGETTEXTFLAGS_ALL) --omit-header --force-po --output "$@" "$<"


# tools translation catalogues depends on their source file
$(POT_DIR)/%.pot: $(TOOLS_DIR)/%.sh
	@echo "## (re-)generating '$@' from '$<' ..."
	@$(XGETTEXT) $(XGETTEXTFLAGS) $(XGETTEXTFLAGS_ALL) --omit-header --force-po --output "$@" "$<"


# create all required directories
$(DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p "$@"


# create all install directories
$(INST_DIRS):
	$(PRE_INSTALL)
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0750 "$@"


# install main tools
$(INST_MAIN_SCRIPT): $(MAIN_SCRIPT) 
	@echo "## Installing main script '$(notdir $<)' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"
	@$(call replace_var_in_file,PACKAGE_NAME,$(PACKAGE_NAME),$@)
	@$(call replace_var_in_file,VERSION,$(PACKAGE_VERS),$@)
	@$(foreach name,$(dirs_var_name),$(call replace_var_in_file,$(name),$($(name)),$@))


# install default configuration
$(INST_CONFIG_DEFAULT): $(CONFIG_DEFAULT)
	@echo "## Installing default configuration '$(notdir $<)' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"


# install includes
$(DESTDIR)$(libdir)/$(PACKAGE_NAME)/include/%.inc.sh: $(INCLUDE_DIR)/%.inc.sh
	@echo "## Installing include '$(notdir $<)' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"


# install tools
$(DESTDIR)$(libdir)/$(PACKAGE_NAME)/tools/%.sh: $(TOOLS_DIR)/%.sh
	@echo "## Installing tools '$(notdir $<)' to '$@'"
	@$(INSTALL_PROGRAM) "$<" "$@"
	@$(call replace_var_in_file,PACKAGE_NAME,$(PACKAGE_NAME),$@)
	@$(foreach name,$(dirs_var_name),$(call replace_var_in_file,$(name),$($(name)),$@))


# install hook
$(INST_HOOK): $(DESTDIR)$(libdir)/$(PACKAGE_NAME)/tools/$(notdir $(HOOK_SCRIPT))
	@echo "## Installing initramfs hook (symlink) from '$<' to '$@'"
	@ln -s "$<" "$@"


# install locales
$(DESTDIR)$(localedir)/%/LC_MESSAGES/$(TEXTDOMAIN).mo: $(MO_DIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo
	@echo "## Installing locale '$*' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"


# install man files
$(DESTDIR)$(mandir)/%/man$(MAN_SECTION)/$(PACKAGE_NAME).$(MAN_SECTION).gz: $(MAN_DIR)/%.texi.gz
	@echo "## Installing man '$*' to '$@'"
	@$(INSTALL_DATA) "$<" "$@"


# install examples
$(DESTDIR)$(sysconfdir)/$(PACKAGE_NAME)/%: $(EXAMPLES_DIR)/%
	@if [ ! -e "$@" ]; then \
		echo "## Installing configuration example '$(notdir $<)' to '$@'"; \
		$(INSTALL_DATA) "$<" "$@"; \
	fi;


# to build everything, create directories then 
# all the man files (they depends on all the rest)
all: $(DIRS) $(MANS)


# install all files to their proper location
install: all $(INST_DIRS) $(INST_FILES)


# uninstall
uninstall:
	@$(RM) $(INST_FILES)
	-@rmdir --parents $(INST_DIRS) 2>/dev/null||true


# cleanup
clean:
	@$(RM) -r $(TMPDIR) $(LOCALE_DIR)/*~ $(srcdir)/*~


# check
check:
	@echo "## Testing is not yet implemented... Sorry! :-("


# create all dist directories
$(DIST_DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p -m 0755 "$@"


# copy (hard link) source files
$(DIST_DIRPATH)/%: $(srcdir)/%
	@echo "## Copying source file '$<' to '$@'"
	@ln "$<" "$@"


# distribution tarball
$(DIST_TARPATH): $(DIST_FILES)
	@echo "## Creating distribution tarball '$@'"
	@$(TAR) $(TARFLAGS) $(DIST_TARFLAGS)


# create a distribution tarball
dist: all $(DIST_DIRS) $(DIST_TARPATH)


# dist cleanup
distclean: clean


# catch-all
.PHONY: all install uninstall clean check dist distclean deb maintainer-clean list-files

# vim:set ts=4 sw=4
