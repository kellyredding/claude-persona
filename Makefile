.PHONY: build install clean test lint format check dev

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
BUILDDIR ?= build

# Development
test:
	crystal spec

lint:
	crystal tool format --check src spec

format:
	crystal tool format src spec

# check builds dev binary first (integration specs need it)
check: lint dev test

dev:
	@mkdir -p $(BUILDDIR)
	crystal build -o $(BUILDDIR)/claude-persona src/claude_persona.cr

# Release
build:
	@mkdir -p $(BUILDDIR)
	shards install
	crystal build --release --no-debug -o $(BUILDDIR)/claude-persona src/claude_persona.cr

install: build
	install -d $(BINDIR)
	install -m 755 $(BUILDDIR)/claude-persona $(BINDIR)/claude-persona

clean:
	rm -rf $(BUILDDIR) lib .shards releases
