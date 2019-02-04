# Makefile for cryptkey-from-usb-mtp
#
# Author : Michael Bideau
# Licence: GPLv3+
#

# source
SRC_DIR        ?= .
SRC_FILE       := $(SRC_DIR)/cryptkey-from-usb-mtp.sh

# destination
DEST_DIR_BASE  := usr/share

# package infos
PACKAGE_NAME   := $(basename $(notdir $(SRC_FILE)))
PACKAGE_VERS   := 0.0.1

# locale specific
MAIL_BUGS_TO   := mica.devel@gmail.com
TEXTDOMAIN     := messages
SRC_LOCALEDIR  := $(SRC_DIR)/locale
POT_FILE       := $(SRC_DIR)/$(TEXTDOMAIN).pot

# man specific
SRC_MANDIR     := $(SRC_DIR)/man
MAN_SECTION    := 8
MAN_FILENAME   := $(PACKAGE_NAME)

# charset and languages
CHARSET        := UTF-8
LANGS          := fr
LANGS_PLUS_EN  := en $(LANGS)

# binaries
XGETTEXT       := xgettext
MSGFMT         := msgfmt
MSGINIT        := msginit
MSGMERGE       := msgmerge
GZIP           := gzip

# files
LOCALE_DIRS    = $(LANGS:%=$(SRC_LOCALEDIR)/%/LC_MESSAGES)
PO             = $(addsuffix /$(TEXTDOMAIN).po,$(LOCALE_DIRS))
MO             = $(addsuffix /$(TEXTDOMAIN).mo,$(LOCALE_DIRS))
MAN_DIRS       = $(LANGS_PLUS_EN:%=$(SRC_MANDIR)/%/man$(MAN_SECTION))
MANS           = $(addsuffix /$(MAN_FILENAME).$(MAN_SECTION).gz,$(MAN_DIRS))
DIRS           = $(LOCALE_DIRS) $(MAN_DIRS)

# msginit and msgmerge use the WIDTH to break lines
WIDTH          := 80

# Use theses suffixes in rules
.SUFFIXES: .po .mo .pot .gz

# Do not delete those files even if they are intermediaries to other targets
.PRECIOUS: %.mo

# special case for english manual that do not depends on any translation
$(SRC_MANDIR)/en/man$(MAN_SECTION)/$(MAN_FILENAME).$(MAN_SECTION).gz: $(SRC_FILE)
	@if [ ! -e "$<" ]; then \
		echo "## Creating man page '$@' [en]"; \
	else \
		echo "## Updating man page '$@' [en]"; \
	fi; \
	LANGUAGE=en TEXTDOMAINDIR=$(SRC_LOCALEDIR) $(SRC_FILE) --texinfo|$(GZIP) > "$@"

# manuals depends on translations
$(SRC_MANDIR)/%/man$(MAN_SECTION)/$(MAN_FILENAME).$(MAN_SECTION).gz: $(SRC_LOCALEDIR)/%/LC_MESSAGES/$(TEXTDOMAIN).mo
	@_lang="`dirname "$@"|xargs dirname|xargs basename`"; \
	if [ ! -e "$<" ]; then \
		echo "## Creating man page '$@' [$$_lang]"; \
	else \
		echo "## Updating man page '$@' [$$_lang]"; \
	fi; \
	LANGUAGE=$$_lang TEXTDOMAINDIR=$(SRC_LOCALEDIR) $(SRC_FILE) --texinfo|$(GZIP) > "$@"

# compiled translations depends on their not-compiled sources
%.mo: %.po
	@echo "## Compiling catalogue '$<' to '$@'"
	@$(MSGFMT) --check --check-compatibility --output "$@" "$<"

# translations files depends on the main translation catalogue
%.po: $(POT_FILE)
	@_lang="`dirname "$@"|xargs dirname|xargs basename`"; \
	if [ ! -e "$@" ]; then \
		_lang_U="`echo "$$_lang"|tr '[[:lower:]]' '[[:upper:]]'`"; \
		echo "## Initializing catalogue '$@' from '$<' [$${_lang}_$${_lang_U}.$(CHARSET)]"; \
		$(MSGINIT) --no-translator --input "$<" --locale="$${_lang}_$${_lang_U}.$(CHARSET)" --width=$(WIDTH) --output "$@" >/dev/null; \
	else \
		echo "## Updating catalogue '$@' from '$(POT_FILE)' [$${_lang}]"; \
		$(MSGMERGE) --quiet --lang=$$_lang --update "$@" "$<"; \
		touch "$@"; \
	fi

# main translation catalogue depends on the source file
$(POT_FILE): $(SRC_FILE)
	@echo "## (re-)generating '$@' from '$<' ..."
	@$(XGETTEXT) --keyword --keyword=_t --language=shell --from-code=$(CHARSET) \
				  --width=$(WIDTH) --sort-output \
				  --foreign-user \
				  --package-name="$(PACKAGE_NAME)" --package-version="$(PACKAGE_VERS)" \
				  --msgid-bugs-address="$(MAIL_BUGS_TO)" \
				  --output "$@" "$<"

# create all required directories
$(DIRS):
	@echo "## Creating directory '$@'"
	@mkdir -p "$@"

# to build everything, create directories then 
# all the man files (they depends on all the rest)
all: $(DIRS) $(MANS)

# install all files to their proper location
install: all
	@for _f in $(MO) $(MANS); do \
		_dest="$(DESTDIR)/$(DEST_DIR_BASE)/$$_f" ;\
		_dir="`dirname "$$_dest"`" ;\
		install -d "$$_dir" ;\
		echo "## Installing '$$_dest'"; \
		install -m 644 "$$_f" "$$_dest" ;\
	done

# cleanup
clean:
	@$(RM) $(POT_FILE) $(MO) $(addsuffix ~,$(PO)) $(MANS) *~

# catch-all
.PHONY: all clean install

# vim:set ts=4 sw=4
