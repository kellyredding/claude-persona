# Releasing claude-persona

This document describes how to create releases and distribute binaries.

## Prerequisites

- Crystal installed (`crystal --version`)
- GitHub CLI installed and authenticated (`gh auth status`)
- Push access to the repository

## First-Time Setup

Make the release scripts executable:

```bash
chmod +x bin/release bin/release-add
```

## Creating a New Release

### 1. Update the Version

Edit `VERSION.txt` with the new version number:

```bash
echo "0.2.0" > VERSION.txt
```

Version must be in `X.Y.Z` format (semver).

### 2. Run the Release Script

From your primary development machine (ARM Mac):

```bash
bin/release
```

This will:
- Sync version to `shard.yml`, source code, and test fixtures
- Build optimized release binary
- Run test suite
- Create tarball with SHA256 checksum
- Commit version bump
- Create and push git tag
- Create GitHub release with macOS ARM64 binary

### 3. Add Additional Platforms (Optional)

To add binaries for other platforms, run `bin/release-add` on each target machine:

**On an Intel Mac:**
```bash
git pull origin main
bin/release-add
# Uploads claude-persona-X.Y.Z-darwin-amd64.tar.gz
```

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

## Platform Detection

The `bin/release-add` script auto-detects the current platform:

| Machine | Artifact Name |
|---------|---------------|
| Apple Silicon Mac | `darwin-arm64` |
| Intel Mac | `darwin-amd64` |
| Linux x64 | `linux-amd64` |
| Linux ARM64 | `linux-arm64` |

## Release Artifacts

Each release includes:
- `claude-persona-X.Y.Z-<os>-<arch>.tar.gz` - Compressed binary
- `claude-persona-X.Y.Z-<os>-<arch>.tar.gz.sha256` - Checksum file

## Verifying Downloads

Users can verify download integrity:

```bash
shasum -a 256 -c claude-persona-0.1.0-darwin-arm64.tar.gz.sha256
```

## Installing from Release

```bash
# Download and extract (replace X.X.X with actual version)
curl -L -o claude-persona.tar.gz \
  https://github.com/kellyredding/claude-persona/releases/download/vX.X.X/claude-persona-X.X.X-darwin-arm64.tar.gz
tar -xzf claude-persona.tar.gz

# Move to PATH
mv claude-persona-X.X.X-darwin-arm64 /usr/local/bin/claude-persona
chmod +x /usr/local/bin/claude-persona

# Verify
claude-persona version
```

## Troubleshooting

### "Tag already exists"

The version in `VERSION.txt` has already been released. Increment the version number.

### "Release doesn't exist" (when running release-add)

Run `bin/release` on your primary machine first to create the release.

### Build fails on Linux

Ensure Crystal and its dependencies are installed:
```bash
# Ubuntu/Debian
apt-get install crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev
```

## Version Locations

Version is defined in these places, all synced by `bin/release`:
- `VERSION.txt` - Source of truth
- `shard.yml` - Crystal package version
- `src/claude_persona.cr` - `VERSION` constant
- `spec/fixtures/personas/*.toml` - Test fixtures
