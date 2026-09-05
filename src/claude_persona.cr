require "./claude_persona/*"

module ClaudePersona
  VERSION = {{ read_file("#{__DIR__}/../VERSION.txt").strip }}

  # Allow override via environment variable for testing
  CONFIG_DIR   = Path.new(ENV.fetch("CLAUDE_PERSONA_CONFIG_DIR", (Path.home / ".claude-persona").to_s))
  PERSONAS_DIR = CONFIG_DIR / "personas"
  MCP_DIR      = CONFIG_DIR / "mcp"
end

ClaudePersona::CLI.run(ARGV)
