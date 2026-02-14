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

Download the latest binary from [Releases](https://github.com/kellyredding/claude-persona/releases) and place it in your PATH. Since Claude Code installs to `~/.local/bin`, that's a good location:

```bash
# Download tarball and checksum (check Releases page for latest version)
# Use darwin-arm64 for Apple Silicon, darwin-amd64 for Intel
curl -LO https://github.com/kellyredding/claude-persona/releases/download/vX.X.X/claude-persona-X.X.X-darwin-arm64.tar.gz
curl -LO https://github.com/kellyredding/claude-persona/releases/download/vX.X.X/claude-persona-X.X.X-darwin-arm64.tar.gz.sha256

# Verify checksum (should say "OK")
shasum -a 256 -c claude-persona-X.X.X-darwin-arm64.tar.gz.sha256

# Extract and install
tar -xzf claude-persona-X.X.X-darwin-arm64.tar.gz
mv claude-persona-X.X.X-darwin-arm64 ~/.local/bin/claude-persona
chmod +x ~/.local/bin/claude-persona

# Clean up
rm claude-persona-X.X.X-darwin-arm64.tar.gz claude-persona-X.X.X-darwin-arm64.tar.gz.sha256
```

Or build from source (requires Crystal):

```bash
git clone https://github.com/kellyredding/claude-persona.git
cd claude-persona
make install
```

## Quick Start

1. **Import your MCP configs from Claude**
   ```bash
   claude-persona mcp import-all
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
claude-persona <name> -p "prompt"  # One-shot: print response and exit
claude-persona <name> --dry-run    # Show command without executing
claude-persona list                # List all available personas
claude-persona show <name>         # Display persona configuration
claude-persona generate            # Create new persona interactively
claude-persona rename <old> <new>  # Rename a persona
claude-persona remove <name>       # Delete a persona (prompts for confirmation)
```

The `list` command shows personas with their paths for easy discovery:

```
Available personas:

  researcher
    Technical research assistant for exploration and planning
    Model: opus
    MCPs: context7, linear-server
    Permission mode: default
    Path: /Users/kelly/.claude-persona/personas/researcher.toml

```

### MCP Management

MCPs are configured in Claude first, then imported to claude-persona. The import reads directly from Claude's config files (`~/.claude.json` for user-scope, `.claude.json` for project-scope).

```bash
# See what MCPs are available to import (from Claude's config)
claude-persona mcp available

# Import MCPs to claude-persona
claude-persona mcp import context7
claude-persona mcp import-all     # Import all at once

# Manage imported configs
claude-persona mcp list           # List imported configs
claude-persona mcp show <name>    # Display imported config JSON
claude-persona mcp remove <name>  # Delete imported config (prompts for confirmation)
```

The `mcp available` command shows MCPs from both scopes:

```
Available MCP servers to import:

User scope (~/.claude.json):
  context7 (http)
  google-calendar (stdio)

Project scope (/path/to/project/.claude.json):
  (none available)
```

The `mcp list` command shows imported configs with their paths:

```
MCP configs:
  context7 (http): /Users/kelly/.claude-persona/mcp/context7.json
  google-calendar (stdio): /Users/kelly/.claude-persona/mcp/google-calendar.json
  linear-server (sse): /Users/kelly/.claude-persona/mcp/linear-server.json
```

### Generate Command

Create a new persona interactively:

```bash
claude-persona generate
```

This launches Claude (using Opus) to interview you and create a persona config. The generator asks about:

- **Developer role** - Backend, frontend, full-stack, DevOps, code reviewer, research assistant, personal assistant, or something unique
- **Model selection** - Opus for complex reasoning, Sonnet for balanced, Haiku for fast/cheap
- **Directory access** - Which directories the persona should have access to
- **MCP servers** - External integrations (must be imported first)
- **Tool permissions** - Any tools to restrict or deny
- **Permission mode** - How much autonomy the persona should have
- **System prompt** - Expertise, communication style, startup routines
- **Initial message** (optional) - Message that triggers Claude to act immediately on launch

After the interview, Claude proposes a name, shows a preview of the config, and writes it to `~/.claude-persona/personas/<name>.toml`.

```
✨ Claude Persona Generator
   Model: opus
   Directories:
     - ~/.claude-persona/personas
     - ~/.claude-persona/mcp
   Allowed tools: Read, Write, Glob, AskUserQuestion

   Claude will interview you and create a new persona config.

```

## Configuration

### Directory Structure

```
~/.claude-persona/
├── personas/           # Persona TOML files
│   ├── assistant.toml
│   └── rails-dev.toml
└── mcp/               # Imported MCP JSON configs
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
allowed = ["Read", "Write", "Edit", "Bash", "WebSearch", "WebFetch"]
# disallowed = ["Bash(rm:*)"]

[permissions]
mode = "default"  # default, acceptEdits, bypassPermissions, plan

[prompt]
system = """
You are a Ruby on Rails expert...

On startup:
1. Read coding guidelines at ~/projects/guidelines/ruby-style.md
2. ...
"""

# Optional: initial message triggers Claude to respond immediately on launch
# initial_message = "Begin your analysis of the codebase..."
```

### MCP Format (JSON)

Imported automatically via `claude-persona mcp import`. Format matches Claude's MCP config:

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

When resuming a session with vibe mode and auto-start:

```
🔄 Resuming persona: assistant (session a1b2c3d4...)
   Model: opus
   Directories:
     - /Users/kelly/projects
   MCPs: google-calendar
   😎 Vibe mode
   💬 Auto-start enabled

```

The `😎 Vibe mode` indicator shows when `--vibe` is used. The `💬 Auto-start enabled` indicator shows when the persona has an `initial_message` configured.

## Session Summary

After each session, claude-persona displays:

```
==================================================
🏁 Claude Persona Summary
==================================================
Persona:  rails-dev
Model:    sonnet
Runtime:  45m 23s
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

## Initial Message (Auto-Start)

Personas can include an `initial_message` that triggers Claude to act immediately on launch, without waiting for you to type anything:

```toml
[prompt]
system = "You are a personal assistant..."
initial_message = "Check my calendar and summarize today's schedule."
```

When launched, Claude will immediately respond to the initial message. This is useful for:
- **Personal assistants** that check calendar, tasks, or provide daily briefings
- **Automation personas** that run checks or generate reports
- **Research personas** that begin analyzing immediately

The launch display shows `💬 Auto-start enabled` when this is configured.

## Print Mode (One-Shot)

Run a persona non-interactively — send a single prompt, get the response, and exit:

```bash
claude-persona rails-dev -p "What files handle user authentication?"
```

This applies the full persona configuration (system prompt, model, tools, MCPs, directories) but runs Claude in non-interactive mode. The response is printed to stdout and the process exits.

### JSON Output

Get structured JSON output for programmatic use:

```bash
claude-persona rails-dev -p "List the API endpoints" --output-format json
```

The JSON response includes the result, token usage, and session info:

```json
{
  "type": "result",
  "subtype": "success",
  "result": "Here are the API endpoints...",
  "session_id": "..."
}
```

### Use Cases

- **Scripting**: Automate tasks using persona expertise
- **Agent delegation**: Have one Claude session delegate work to a persona
- **CI/CD**: Run code analysis or reviews in pipelines
- **Composability**: Chain persona calls in shell scripts

Print mode automatically adds `--no-session-persistence` since one-shot calls don't need session history.

Works with other flags:
```bash
claude-persona rails-dev -p "Review this code" --output-format json --vibe
claude-persona rails-dev -p "Analyze performance" --dry-run
```

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

When a persona has an `initial_message`, the dryrun shows the `--` separator:

```
# claude-persona v0.1.0
claude \
  --model opus \
  --system-prompt "You are a personal assistant..." \
  --add-dir /Users/kelly/projects \
  -- "Check my calendar and summarize today's schedule."
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

## Bash Completion

A bash completion script is included for tab-completing commands, flags, persona names, and MCP names.

### Installation

Source the script in your shell profile (e.g., `~/.bashrc` or `~/.bash_profile`):

```bash
source /path/to/claude-persona/completions/claude-persona.bash
```

Or copy to a bash-completion directory:

```bash
# Linux
cp completions/claude-persona.bash /etc/bash_completion.d/claude-persona

# macOS with Homebrew
cp completions/claude-persona.bash /usr/local/etc/bash_completion.d/claude-persona
```

### Usage

Once installed, tab completion works for:

- **Commands**: `claude-persona <TAB>` shows `list`, `generate`, `show`, `mcp`, etc.
- **Persona names**: `claude-persona show <TAB>` lists your personas
- **MCP subcommands**: `claude-persona mcp <TAB>` shows `available`, `import`, `list`, etc.
- **MCP names**: `claude-persona mcp show <TAB>` lists your imported MCPs
- **Flags**: `claude-persona --<TAB>` shows `--vibe`, `--dry-run`, `--resume`, etc.

### Using with Aliases

If you alias `claude-persona` to something shorter, add completion for your alias:

```bash
alias persona='claude-persona'
complete -F _claude_persona persona
```

Now `persona <TAB>` works just like `claude-persona <TAB>`.

### Creating Completions for Other Shells

The completion script in `completions/claude-persona.bash` can serve as a template for creating completions for other shells (zsh, fish). The key patterns:

- Dynamically fetch persona names via `claude-persona list`
- Dynamically fetch MCP names via `claude-persona mcp list` and `claude-persona mcp available`
- No hardcoded paths - all lookups use the CLI itself

## Troubleshooting

### MCP not showing in `mcp available`

The `mcp available` command reads directly from Claude's config files:
- User scope: `~/.claude.json`
- Project scope: `.claude.json` in current directory

If an MCP doesn't appear:
1. Verify it's configured in Claude with `claude mcp list`
2. Check you're in the correct directory for project-scoped MCPs
3. Ensure the config file exists and contains valid JSON

### Persona not found after generation

The generator relies on Claude to write the file with the confirmed name. If the file wasn't created:
1. Check `~/.claude-persona/personas/` for the file
2. Re-run `claude-persona generate` and ensure you confirm the name before Claude writes

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and contribution guidelines.

## License

[MIT](LICENSE)
