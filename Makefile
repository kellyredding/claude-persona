.PHONY: build install clean test lint format check dev

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
BUILDDIR ?= build

# Development
test:
	crystal spec

lint:
	crystal tool format --check src spec

format:
	crystal tool format src spec

# `dev` first: the integration specs exercise the built binary as a
# subprocess, so they have nothing to run until it exists.
check: dev test lint

dev: format
	@mkdir -p $(BUILDDIR)
	shards install
	crystal build -o $(BUILDDIR)/claude-persona src/claude_persona.cr

# Release
build:
	@mkdir -p $(BUILDDIR)
	shards install
	crystal build --release --no-debug -o $(BUILDDIR)/claude-persona src/claude_persona.cr

# Two compilations on purpose. `check` validates behavior against the dev
# binary; `build` produces the optimized artifact that gets installed.
# Collapsing them would ship a binary no spec ever ran against.
install: check build
	install -d $(BINDIR)
	install -m 755 $(BUILDDIR)/claude-persona $(BINDIR)/claude-persona

clean:
	rm -rf $(BUILDDIR) lib .shards releases
