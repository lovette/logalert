#!/usr/bin/make -f

SBINDIR = usr/sbin
CONFDIR = etc/logalert
MANDIR = usr/share/man/man8

all:

install:
	# Create directories
	install -d $(DESTDIR)/$(SBINDIR)
	install -d $(DESTDIR)/$(CONFDIR)
	install -d $(DESTDIR)/$(MANDIR)

	# Install admin scripts
	install -m 755 src/logalert.sh $(DESTDIR)/$(SBINDIR)/logalert

	# Install config files
	install -m 644 src/default.* $(DESTDIR)/$(CONFDIR)

	# Install man page
	gzip -c docs/logalert.8 > $(DESTDIR)/$(MANDIR)/logalert.8.gz

uninstall:
	# Remove state directory
	-$(DESTDIR)/$(SBINDIR)/logalert -u
	
	# Remove admin scripts
	-rm -f  $(DESTDIR)/$(SBINDIR)/logalert

	# Remove config files
	-rm -f $(DESTDIR)/$(CONFDIR)/default.*

	# Remove man page
	-rm -f $(DESTDIR)/$(MANDIR)/logalert.8.gz

help2man:
	help2man -n "scan logs and email activity to a sysadmin" -s 8 -N -i docs/logalert.8.inc -o docs/logalert.8 "bash src/logalert.sh"
