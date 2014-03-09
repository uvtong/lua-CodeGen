
LUA     := lua
VERSION := $(shell cd src && $(LUA) -e "m = require [[CodeGen]]; print(m._VERSION)")
TARBALL := lua-codegen-$(VERSION).tar.gz
REV     := 1

LUAVER  := 5.1
PREFIX  := /usr/local
DPREFIX := $(DESTDIR)$(PREFIX)
LIBDIR  := $(DPREFIX)/share/lua/$(LUAVER)
INSTALL := install

all: dist.cmake
	@echo "Nothing to build here, you can just make install"

install: install.common
	$(INSTALL) -m 644 -D src/CodeGen.lua                    $(LIBDIR)/CodeGen.lua

install.lpeg: install.common
	$(INSTALL) -m 644 -D src/CodeGen/lpeg.lua               $(LIBDIR)/CodeGen.lua

install.common:
	$(INSTALL) -m 644 -D src/CodeGen/Graph.lua              $(LIBDIR)/CodeGen/Graph.lua

uninstall:
	rm -f $(LIBDIR)/CodeGen.lua
	rm -f $(LIBDIR)/CodeGen/Graph.lua

manifest_pl := \
use strict; \
use warnings; \
my @files = qw{MANIFEST}; \
while (<>) { \
    chomp; \
    next if m{^\.}; \
    next if m{^doc/\.}; \
    next if m{^doc/google}; \
    next if m{^rockspec/}; \
    push @files, $$_; \
} \
print join qq{\n}, sort @files;

rockspec_pl := \
use strict; \
use warnings; \
use Digest::MD5; \
open my $$FH, q{<}, q{$(TARBALL)} \
    or die qq{Cannot open $(TARBALL) ($$!)}; \
binmode $$FH; \
my %config = ( \
    version => q{$(VERSION)}, \
    rev     => q{$(REV)}, \
    md5     => Digest::MD5->new->addfile($$FH)->hexdigest(), \
); \
close $$FH; \
while (<>) { \
    s{@(\w+)@}{$$config{$$1}}g; \
    print; \
}

version:
	@echo $(VERSION)

CHANGES: dist.info
	perl -i.bak -pe "s{^$(VERSION).*}{q{$(VERSION)  }.localtime()}e" CHANGES

dist.info:
	perl -i.bak -pe "s{^version.*}{version = \"$(VERSION)\"}" dist.info

tag:
	git tag -a -m 'tag release $(VERSION)' $(VERSION)

doc:
	git read-tree --prefix=doc/ -u remotes/origin/gh-pages

dist.cmake:
	wget https://raw.github.com/LuaDist/luadist/master/dist.cmake

MANIFEST: doc dist.cmake
	git ls-files | perl -e '$(manifest_pl)' > MANIFEST

$(TARBALL): MANIFEST
	[ -d lua-CodeGen-$(VERSION) ] || ln -s . lua-CodeGen-$(VERSION)
	perl -ne 'print qq{lua-CodeGen-$(VERSION)/$$_};' MANIFEST | \
	    tar -zc -T - -f $(TARBALL)
	rm lua-CodeGen-$(VERSION)
	rm -rf doc
	git rm doc/*

dist: $(TARBALL)

rockspec: $(TARBALL)
	perl -e '$(rockspec_pl)' rockspec.in > rockspec/lua-codegen-$(VERSION)-$(REV).rockspec

install-rock: clean dist rockspec
	perl -pe 's{http://cloud.github.com/downloads/fperrad/lua-CodeGen/}{};' \
	    rockspec/lua-codegen-$(VERSION)-$(REV).rockspec > lua-codegen-$(VERSION)-$(REV).rockspec
	luarocks install lua-codegen-$(VERSION)-$(REV).rockspec

check: test

test:
	cd src && prove --exec=$(LUA) ../test/*.t
	cd src && prove --exec="$(LUA) -l CodeGen.lpeg" ../test/*.t

coverage:
	rm -f src/luacov.stats.out src/luacov.report.out
	-cd src && prove --exec="$(LUA) -lluacov" ../test/*.t
	cd src && luacov

README.html: README.md
	Markdown.pl README.md > README.html

clean:
	rm -rf doc
	rm -f MANIFEST *.bak src/luacov.*.out *.rockspec README.html

realclean: clean
	rm -f dist.cmake

.PHONY: test rockspec CHANGES dist.info

