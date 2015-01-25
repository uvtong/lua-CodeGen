
LUA     := lua
VERSION := $(shell cd src && $(LUA) -e "m = require [[CodeGen]]; print(m._VERSION)")
TARBALL := lua-codegen-$(VERSION).tar.gz
REV     := 1

LUAVER  := 5.1
PREFIX  := /usr/local
DPREFIX := $(DESTDIR)$(PREFIX)
LIBDIR  := $(DPREFIX)/share/lua/$(LUAVER)
INSTALL := install

all:
	@echo "Nothing to build here, you can just make install"

install: install.lua

install.lua: install.common
	$(INSTALL) -m 644 -D src/CodeGen.lua                    $(LIBDIR)/CodeGen.lua

install.lpeg: install.common
	$(INSTALL) -m 644 -D src.lpeg/CodeGen.lua               $(LIBDIR)/CodeGen.lua

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

MANIFEST: doc
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
	perl -e '$(rockspec_pl)' rockspec.in      > rockspec/lua-codegen-$(VERSION)-$(REV).rockspec
	perl -e '$(rockspec_pl)' rockspec.lpeg.in > rockspec/lua-codegen-lpeg-$(VERSION)-$(REV).rockspec

rock:
	luarocks pack rockspec/lua-codegen-$(VERSION)-$(REV).rockspec
	luarocks pack rockspec/lua-codegen-lpeg-$(VERSION)-$(REV).rockspec

check: test

test: test.lua test.lpeg

test.lua:
	cd src && prove --exec=$(LUA) ../test/*.t

test.lpeg: src.lpeg/CodeGen/Graph.lua
	cd src.lpeg && prove --exec=$(LUA) ../test/*.t

luacheck:
	luacheck --std=max --codes src --ignore 212 --ignore 421
	luacheck --std=max --codes src.lpeg --ignore 212 --ignore 421
	luacheck --std=min --config .test.luacheckrc test/*.t

src.lpeg/CodeGen:
	mkdir src.lpeg/CodeGen

src.lpeg/CodeGen/Graph.lua: src.lpeg/CodeGen src/CodeGen/Graph.lua
	cp src/CodeGen/Graph.lua src.lpeg/CodeGen/Graph.lua

coverage:
	rm -f src/luacov.stats.out src/luacov.report.out
	-cd src && prove --exec="$(LUA) -lluacov" ../test/*.t
	cd src && luacov

coveralls:
	rm -f src/luacov.stats.out src/luacov.report.out
	-cd src && prove --exec="$(LUA) -lluacov" ../test/*.t
	cd src && luacov-coveralls -e ^/usr -e test/ -e %.t$

README.html: README.md
	Markdown.pl README.md > README.html

clean:
	rm -rf doc
	rm -rf src.lpeg/CodeGen
	rm -f MANIFEST *.bak src/luacov.*.out *.rockspec README.html

realclean: clean

.PHONY: test rockspec CHANGES dist.info

