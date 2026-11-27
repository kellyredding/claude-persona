.PHONY: build install clean test lint format check dev

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
BUILDDIR ?= build

# The linker takes the binary's minimum macOS from this. Unset, it is the
# building Mac's own version, and older Macs refuse to start the binary.
export MACOSX_DEPLOYMENT_TARGET = 15.0

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

# Release. Universal: Apple Silicon natively, then Intel cross-compiled.
# Crystal only compiles the Intel object and prints the link command, so it is
# run with `-arch x86_64` added; Crystal's bundled static libraries hold both.
build:
	@mkdir -p $(BUILDDIR)
	shards install
	crystal build --release --no-debug -o $(BUILDDIR)/claude-persona-arm64 src/claude_persona.cr
	crystal build --release --no-debug --cross-compile --target x86_64-apple-macosx$(MACOSX_DEPLOYMENT_TARGET) \
	  -o $(BUILDDIR)/claude-persona-x86_64 src/claude_persona.cr > $(BUILDDIR)/link-x86_64.sh
	sh -c "$$(sed 's/^cc /cc -arch x86_64 /' $(BUILDDIR)/link-x86_64.sh)"
	lipo -create -output $(BUILDDIR)/claude-persona $(BUILDDIR)/claude-persona-arm64 $(BUILDDIR)/claude-persona-x86_64

# Two compilations on purpose. `check` validates behavior against the dev
# binary; `build` produces the optimized artifact that gets installed.
# Collapsing them would ship a binary no spec ever ran against.
install: check build
	install -d $(BINDIR)
	install -m 755 $(BUILDDIR)/claude-persona $(BINDIR)/claude-persona

clean:
	rm -rf $(BUILDDIR) lib .shards releases
