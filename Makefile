CURL = curl
WGET = wget
GIT = git

all: data

clean:

updatenightly: updatenightly-0 updatebyhook

updatenightly-0:
	$(CURL) -s -S -L https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add bin/modules
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl

updatebyhook: data

## ------ Setup ------

PERL = ./perl

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Build ------

data: deps local-swdata data-main

data-main: extract

local-swdata: local-swdata-repo local-swdata-grep

local-swdata-repo:
	$(GIT) clone --depth 1 https://github.com/suikawiki/suikawiki-data local/data || \
	(cd local/data && $(GIT) fetch --depth 1 origin master && $(GIT) checkout origin/master)

local-swdata-grep:
	cd local/data && $(GIT) grep '^\[FIG' ids/ | grep 'data' > ../../local/files.txt

extract: bin/extract.pl local/files.txt
	$(PERL) bin/extract.pl

## ------ Tests ------

test: test-main test-deps

test-deps: deps

test-main:
	$(PERL) -c bin/extract.pl

## License: Public Domain.
