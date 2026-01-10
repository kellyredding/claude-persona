# claude-persona

Launch Claude Code with pre-configured personas - named configurations that define system prompts, models, directory permissions, tool permissions, and MCP server configurations.

## Why?

Claude Code is powerful, but starting fresh sessions means reconfiguring your preferred setup each time. Different tasks benefit from different configurations:

- **Assistant persona**: Needs calendar and task management MCPs, broad directory access
- **Rails developer persona**: Needs only Context7 MCP for docs, focused directory access, specific coding guidelines
- **Researcher persona**: Needs web search tools, minimal MCPs to preserve context for research

`claude-persona` lets you define these configurations once and launch them by name.

## Prerequisites

- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) must be installed and configured

## Installation

Download the latest binary from [Releases](https://github.com/kellyredding/claude-persona/releases) and place it in your PATH:

```bash
# Download and extract (check Releases page for latest version)
curl -L https://github.com/kellyredding/claude-persona/releases/download/vX.X.X/claude-persona-X.X.X-darwin-arm64.tar.gz | tar -xz
mv claude-persona-X.X.X-darwin-arm64 ~/bin/claude-persona
chmod +x ~/bin/claude-persona
```

Or build from source (requires Crystal):

```bash
git clone https://github.com/kellyredding/claude-persona.git
cd claude-persona
make install
```

## Quick Start

1. **Export your MCP configs from Claude**
   ```bash
   claude-persona mcp export-all
   ```

2. **Create a persona**
   ```bash
   claude-persona generate
   ```
   Claude will interview you and create the config file.

3. **Launch your persona**
   ```bash
   claude-persona rails-dev
   ```

## Commands

### Persona Management

```bash
claude-persona <name>              # Launch Claude with this persona
claude-persona <name> --vibe       # Launch with permissions skipped
claude-persona <name> --dry-run    # Show command without executing
claude-persona list                # List all available personas
claude-persona show <name>         # Display persona configuration
claude-persona generate            # Create new persona interactively
claude-persona rename <old> <new>  # Rename a persona
```

### MCP Management

MCPs are configured in Claude first, then exported to claude-persona:

```bash
# First, configure in Claude
claude mcp add --transport http context7 https://mcp.context7.com/mcp

# Then export to claude-persona
claude-persona mcp export context7
claude-persona mcp export-all     # Export all at once

# Manage exported configs
claude-persona mcp list           # List exported configs
claude-persona mcp show <name>    # Display config JSON
claude-persona mcp remove <name>  # Delete exported config
```

## Configuration

### Directory Structure

```
~/.claude-persona/
├── personas/           # Persona TOML files
│   ├── assistant.toml
│   └── rails-dev.toml
└── mcp/               # Exported MCP JSON configs
    ├── context7.json
    └── linear.json
```

### Persona Format (TOML)

```toml
description = "Ruby on Rails developer"
model = "sonnet"  # opus, sonnet, or haiku

[directories]
allowed = [
    "~/projects/myapp",
    "~/projects/guidelines",
]

[mcp]
configs = ["context7"]  # References ~/.claude-persona/mcp/context7.json

[tools]
allowed = ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
# disallowed = ["Bash(rm -rf:*)"]

[permissions]
mode = "default"  # default, acceptEdits, bypassPermissions, plan

[prompt]
system = """
You are a Ruby on Rails expert...

On startup:
1. Read coding guidelines at ~/projects/guidelines/ruby-style.md
2. ...
"""
```

### MCP Format (JSON)

Exported automatically via `claude-persona mcp export`. Format matches Claude's MCP config:

```json
{
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

## Launch Display

When launching a persona, claude-persona shows the configuration being used:

```
🚀 Launching persona: rails-dev
   Model: sonnet
   Directories:
     - /Users/kelly/projects/kajabi
     - /Users/kelly/projects/kajabi/implementation-plans
   MCPs: context7, linear
   Allowed tools: Read, Write, Edit, Bash, Glob, Grep
   Permission mode: default

```

When resuming a session:

```
🔄 Resuming persona: rails-dev (session a1b2c3d4...)
   Model: sonnet
   Directories:
     - /Users/kelly/projects/kajabi
   MCPs: context7
   😎 Vibe mode

```

## Session Summary

After each session, claude-persona displays:

```
==================================================
🏁 Claude Persona Summary
==================================================
Persona:  rails-dev
Model:    sonnet
Runtime:  45m 23s
Cost:     $0.4521
Session:  a1b2c3d4-e5f6-7890-abcd-ef1234567890

Resume:   claude-persona rails-dev --resume a1b2c3d4-e5f6-7890-abcd-ef1234567890
==================================================
```

The resume command applies your full persona config (MCP servers, system prompt, tools) while continuing the conversation. If you launched with `--vibe`, the resume command will include that flag too.

## Vibe Mode

Skip all permission checks for a session:

```bash
claude-persona rails-dev --vibe
```

This passes `--dangerously-skip-permissions` to Claude. Use when you want Claude to work autonomously without approval prompts. The longer `--dangerously-skip-permissions` flag also works as an alias.

Note: This is a runtime flag, not a persona config option. The same persona can be launched with or without vibe mode depending on context.

## Dryrun Mode

Preview the exact command without launching Claude:

```bash
claude-persona rails-dev --dry-run
```

Output:
```
# claude-persona v0.1.0
claude \
  --model sonnet \
  --system-prompt "You are a Ruby on Rails expert..." \
  --add-dir /Users/kelly/projects/kajabi \
  --strict-mcp-config \
  --mcp-config /Users/kelly/.claude-persona/mcp/context7.json \
  --permission-mode default
```

Useful for:
- Debugging persona configurations
- Verifying MCP configs are resolved correctly
- Seeing expanded paths and full system prompts
- CI/CD testing without launching Claude

Works with all flags:
```bash
claude-persona rails-dev --vibe --resume abc123 --dry-run
```

## Troubleshooting

### MCP export fails or produces incorrect config

The `mcp export` command parses the text output of `claude mcp get`. If Claude CLI changes its output format in a future version, export may fail or produce incomplete configs.

**Workaround**: Manually create the MCP JSON file in `~/.claude-persona/mcp/`:

```json
{
  "mcpServers": {
    "your-mcp-name": {
      "type": "http",
      "url": "https://your-mcp-url.com/mcp"
    }
  }
}
```

For stdio servers:
```json
{
  "mcpServers": {
    "your-mcp-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@your/mcp-package"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

### Session cost shows $0.0000

Cost calculation reads Claude's session JSONL files. If the session file can't be found (e.g., due to symlink resolution on macOS), cost will show as zero. The session ID and resume command will still work.

### Persona not found after generation

The generator relies on Claude to write the file with the confirmed name. If the file wasn't created:
1. Check `~/.claude-persona/personas/` for the file
2. Re-run `claude-persona generate` and ensure you confirm the name before Claude writes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and contribution guidelines.

## License

MIT
