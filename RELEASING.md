# Releasing claude-persona

This document describes how to create releases and distribute binaries.

## Prerequisites

- An Apple Silicon Mac: the release builds Apple Silicon natively and
  cross-compiles Intel
- Crystal installed (`crystal --version`)
- GitHub CLI installed and authenticated (`gh auth status`)
- Push access to the repository

## First-Time Setup

Make the release scripts executable:

```bash
chmod +x bin/bump bin/release bin/release-add bin/verify-binary
```

## Branches

Work lands on `development`; feature branches come off it and `development`
fast-forwards to them. `main` is the release branch and only ever
fast-forwards to `development`: nothing is committed on it, not even a version
bump. `main` stays the default branch, because every install fetches
`scripts/update.sh` from it, so a change to that script reaches installs when
`main` moves, at release.

## Creating a New Release

### 1. Bump the Version on `development`

```bash
git checkout development && git pull --ff-only
bin/bump X.Y.Z          # VERSION.txt, shard.yml and the persona fixtures
# write release-notes/vX.Y.Z.md (release-notes/README.md has the format)
git add VERSION.txt shard.yml spec/fixtures/personas release-notes/vX.Y.Z.md
git commit -m "chore(release): bump to X.Y.Z with its notes"
git push origin development
```

Version must be in `X.Y.Z` format (semver).

### 2. Fast-Forward `main`

```bash
git checkout main && git pull --ff-only
git merge --ff-only development
git push origin main
```

If the fast-forward refuses, `main` has a commit `development` lacks: stop and
find out why rather than merging.

### 3. Run the Release Script

From `main`, on an Apple Silicon Mac:

```bash
bin/release --dry-run   # everything up to the tag; prints the release description
bin/release
git checkout development
```

It refuses, before building anything, unless it is on `main` at `origin/main`
with a clean tree, `shard.yml` and the fixtures match `VERSION.txt`, the notes
exist, and the tag is new or already on this commit. Then it:
- Runs `make check`, and refuses if that changed the tree (it formats)
- Builds one universal binary (`make build`): Apple Silicon and Intel, for
  macOS 15 and later
- Verifies it (`bin/verify-binary`): both architectures present, each built
  for macOS 15.0, linking only system libraries, and reporting the version
- Creates the tarball with its SHA256 checksum
- Tags the commit and pushes the tag; it commits nothing
- Creates the GitHub release with the universal macOS binary and the notes

Run it again after a failure: it finishes the tag, its push or the GitHub
release that an earlier run left undone.

### 3. Add a Linux Build (Optional)

Every Mac is covered by the universal binary, so no second Mac is needed.
`bin/release-add` refuses to run on a Mac. To add a Linux build, run it on
the target machine:

**On a Linux x64 machine:**
```bash
git pull origin main
bin/release-add
# Uploads claude-persona-X.Y.Z-linux-amd64.tar.gz
```

**On a Linux ARM machine:**
```bash
git pull origin main
bin/release-add
# Uploads claude-persona-X.Y.Z-linux-arm64.tar.gz
```

## The Universal Build

`make build` compiles Apple Silicon natively, cross-compiles Intel
(`--cross-compile --target x86_64-apple-macosx15.0`, linked with
`-arch x86_64`), and joins the two with `lipo`. Crystal's bundled static
libraries already hold both architectures, so nothing extra is installed.

The Makefile exports `MACOSX_DEPLOYMENT_TARGET = 15.0`. Without it the linker
stamps the building Mac's own macOS version into the binary, and older Macs
refuse to start it.

Check a binary by hand:

```bash
lipo -archs build/claude-persona          # x86_64 arm64
vtool -show-build build/claude-persona    # minos 15.0 for each architecture
bin/verify-binary build/claude-persona
```

## Release Artifacts

Each release includes:
- `claude-persona-X.Y.Z-darwin.tar.gz` - the universal macOS binary, as
  `claude-persona-X.Y.Z-darwin`
- `claude-persona-X.Y.Z-darwin.tar.gz.sha256` - Checksum file
- `claude-persona-X.Y.Z-linux-<arch>.tar.gz` and its checksum, when added

Releases up to 1.6.0 named the macOS architecture instead
(`darwin-arm64`, and `darwin-amd64` when an Intel Mac added it).

## How `claude-persona update` Finds a Release

Every installed version runs `scripts/update.sh` fresh from `main`, so the
script, not the installed binary, decides which asset to download. On a Mac it
tries the universal `-darwin` asset first, then `-darwin-<arch>` for releases
that predate it. A change to that script reaches every install as soon as it
is on `main`, so test it before `main` moves: run a copy with a sandboxed
`HOME` and a `PATH` holding a copy of the binary.

## Verifying Downloads

Users can verify download integrity:

```bash
shasum -a 256 -c claude-persona-0.1.0-darwin.tar.gz.sha256
```

## Installing from Release

```bash
# Download and extract (replace X.X.X with actual version)
curl -L -o claude-persona.tar.gz \
  https://github.com/kellyredding/claude-persona/releases/download/vX.X.X/claude-persona-X.X.X-darwin.tar.gz
tar -xzf claude-persona.tar.gz

# Move to PATH
mv claude-persona-X.X.X-darwin ~/.local/bin/claude-persona
chmod +x ~/.local/bin/claude-persona

# Verify
claude-persona version
```

## Troubleshooting

### "already exists on another commit"

The version in `VERSION.txt` has already been released. Bump it on
`development` with `bin/bump`.

### "shard.yml says … VERSION.txt says …"

The version was changed by hand. Run `bin/bump X.Y.Z` on `development`, which
sets all three locations, and commit the result.

### "releases are built on an Apple Silicon Mac"

The universal build cross-compiles Intel from Apple Silicon. Run `bin/release`
on an Apple Silicon Mac.

### "has no x86_64 code" or "is built for macOS 26.0, not 15.0"

`bin/verify-binary` refused the build. Build with `make build`, which builds
both architectures and sets the deployment target, rather than a plain
`crystal build`.

### "Release doesn't exist" (when running release-add)

Run `bin/release` on your primary machine first to create the release.

### Build fails on Linux

Ensure Crystal and its dependencies are installed:
```bash
# Ubuntu/Debian
apt-get install crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev
```

## Version Locations

`VERSION.txt` is the source of truth. Two further locations are set with it by
`bin/bump`, and `bin/release` refuses when they disagree:
- `shard.yml` - Crystal package version
- `spec/fixtures/personas/*.toml` - Test fixtures

`src/claude_persona.cr` needs no sync. Its `VERSION` constant reads
`VERSION.txt` at compile time, so the literal never appears in Crystal source
and a build always carries whatever the file said.
