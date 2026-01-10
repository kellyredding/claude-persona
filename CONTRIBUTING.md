# Contributing to claude-persona

Thank you for your interest in contributing!

## Development Setup

### Prerequisites

- [Crystal](https://crystal-lang.org/install/) >= 1.0.0
- [GitHub CLI](https://cli.github.com/) (for releases)

### Getting Started

```bash
git clone https://github.com/kellyredding/claude-persona.git
cd claude-persona
shards install
```

## Development Commands

```bash
make check      # Run lint + build + tests (before committing)
make test       # Run specs only
make lint       # Check code formatting
make format     # Auto-format code
make dev        # Build development binary
make build      # Build release binary
make clean      # Remove build artifacts
```

## Development Workflow

1. Make changes to source in `src/`
2. Add/update specs in `spec/`
3. Run `make check` to verify everything passes
4. Run `make format` if lint fails
5. Build with `make dev` to test locally
6. Test manually with `./build/claude-persona`

## Testing

The test suite includes:
- **Unit specs** in `spec/claude_persona/` - test individual components
- **Integration specs** in `spec/integration/` - test CLI dryrun output

Integration specs require the binary to exist. Use `make check` (not just `make test`) to ensure the binary is built first.

```bash
# Run all tests (recommended)
make check

# Run specific spec file
crystal spec spec/claude_persona/command_builder_spec.cr

# Run specific test by line number
crystal spec spec/claude_persona/command_builder_spec.cr:15
```

## Cleanup

To reset the project to a clean state:

```bash
make clean
```

This removes:
- `build/` - compiled binaries
- `lib/` - shard dependencies
- `.shards/` - shard cache
- `releases/` - release tarballs

## Project Structure

```
claude-persona/
├── src/
│   ├── claude_persona.cr          # Entry point
│   └── claude_persona/
│       ├── cli.cr                 # CLI handler
│       ├── config.cr              # TOML config parsing
│       ├── command_builder.cr     # Claude CLI arg builder
│       ├── session.cr             # Session runner + stats
│       ├── mcp_config.cr          # MCP file handling
│       └── generator_prompt.cr    # Persona generator prompt
├── spec/
│   ├── spec_helper.cr
│   ├── fixtures/                  # Test personas and MCPs
│   ├── claude_persona/            # Unit specs
│   └── integration/               # Dryrun integration specs
├── bin/
│   ├── release                    # Release script
│   └── release-add                # Add platform to release
├── build/                         # Compiled binaries (gitignored)
├── releases/                      # Release tarballs (gitignored)
├── shard.yml                      # Dependencies
├── Makefile                       # Build commands
├── VERSION.txt                    # Version source of truth
├── RELEASING.md                   # Release documentation
├── CONTRIBUTING.md                # Development guide
├── LICENSE                        # MIT license
├── .gitignore
├── .editorconfig
└── README.md
```

## Code Style

Crystal code should be formatted using the built-in formatter:

```bash
make format
```

Key conventions:
- 2 spaces for indentation
- No trailing whitespace
- Final newline in all files
- Follow existing patterns in the codebase

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b my-feature`)
3. Make your changes
4. Run `make check` to ensure tests pass
5. Commit your changes with a descriptive message
6. Push to your fork
7. Open a Pull Request

## Questions?

Open an issue for bugs, feature requests, or questions.
