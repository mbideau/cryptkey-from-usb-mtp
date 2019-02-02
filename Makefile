WIDTH          = 80

PACKAGE_NAME   = cryptkey-from-usb-mtp
PACKAGE_VERS   = 0.0.1
MAIL_BUGS_TO   = mica.devel@gmail.com
TEXTDOMAIN     = messages

DEST_LOCALEDIR = usr/share/locale
SRC_DIR        = .
SRC_LOCALEDIR  = $(SRC_DIR)/locale
SRC_FILE       = $(SRC_DIR)/cryptkey-from-usb-mtp.sh
POT_FILE       = $(SRC_DIR)/$(TEXTDOMAIN).pot

CHARSET        = UTF-8
LANGS          = fr

XGETTEXT       = xgettext
MSGFMT         = msgfmt
MSGINIT        = msginit
MSGMERGE       = msgmerge

DIRS = $(LANGS:%=$(SRC_LOCALEDIR)/%/LC_MESSAGES)
PO   = $(addsuffix /$(TEXTDOMAIN).po,$(DIRS))
MO   = $(addsuffix /$(TEXTDOMAIN).mo,$(DIRS))

.SUFFIXES: .po .mo .pot

%.mo: %.po
	-@echo "## Compiling catalogue '$<' to '$@'"
	-@$(MSGFMT) --check --check-compatibility --output "$@" "$<"

all: update $(MO)

update: $(POT_FILE) dirs
	-@for po in $(PO); do \
		_lang="`dirname "$$po"|xargs dirname|xargs basename`"; \
		if [ ! -e "$$po" ]; then \
			_lang_U="`echo "$$_lang"|tr '[[:lower:]]' '[[:upper:]]'`"; \
			echo "## Initializing catalogue '$$po' from '$(POT_FILE)' [$${_lang}_$${_lang_U}.$(CHARSET)]"; \
			$(MSGINIT) --no-translator --input "$(POT_FILE)" --locale="$${_lang}_$${_lang_U}.$(CHARSET)" --width=$(WIDTH) --output "$$po" >/dev/null; \
		else \
			echo "## Updating catalogue '$$po' from '$(POT_FILE)' [$${_lang}]"; \
			$(MSGMERGE) --quiet --lang=$$_lang --update "$$po" "$(POT_FILE)"; \
		fi; \
	done;

dirs:
	-@for d in $(DIRS); do \
		if [ ! -d "$$d" ]; then \
			echo "## Creating directory '$$d'"; \
			mkdir -p "$$d"; \
		fi; \
	done;

$(POT_FILE): $(SRC_FILE)
	-@echo "## (re-)generating '$@' from '$<' ..."
	-@$(XGETTEXT) --keyword --keyword=_t --language=shell --from-code=$(CHARSET) \
				  --width=$(WIDTH) --sort-output \
				  --foreign-user \
				  --package-name="$(PACKAGE_NAME)" --package-version="$(PACKAGE_VERS)" \
				  --msgid-bugs-address="$(MAIL_BUGS_TO)" \
				  --output "$@" "$<"

install: all
	for l in $(LANGS); do \
		t=$(DESTDIR)/$(DEST_LOCALEDIR)/$$l/LC_MESSAGES/ ;\
		install -d "$$t" ;\
		install -m 644 "$$mo" "$$t/$(TEXTDOMAIN).mo" ;\
	done

clean:
	$(RM) $(POT_FILE) $(MO) $(addsuffix ~,$(PO)) *~

.PHONY: all

# vim:set ts=4 sw=4
