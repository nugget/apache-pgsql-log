LIB=        /usr/local/lib
BIN=        /usr/local/bin
TCLSH?=     tclsh8.5
OWNER?=     root
GROUP?=		wheel

INSTALLFILES=	main.tcl config.tcl

PROGNAME=apache_pg_log

all:

install:
	@echo Installing $(PROGNAME)
	install $(BIN)/tcllauncher $(BIN)/$(PROGNAME)
	install -o $(OWNER) -g $(GROUP) -m 0755 -d $(LIB)/$(PROGNAME)
	install -o $(OWNER) -g $(GROUP) -m 0644 $(INSTALLFILES) $(LIB)/$(PROGNAME)
	@sh -c 'git branch --no-color 2> /dev/null' | sed -e '/^[^*]/d' -e 's/* \(.*\)/set ::app_branch "\1"/' > $(LIB)/$(PROGNAME)/version.tcl
	@sh -c 'echo "set ::app_timestamp `date +%s`"' >> $(LIB)/$(PROGNAME)/version.tcl
