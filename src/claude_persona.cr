require "./claude_persona/*"

module ClaudePersona
  VERSION = "1.2.2"

  # Allow override via environment variable for testing
  CONFIG_DIR   = Path.new(ENV.fetch("CLAUDE_PERSONA_CONFIG_DIR", (Path.home / ".claude-persona").to_s))
  PERSONAS_DIR = CONFIG_DIR / "personas"
  MCP_DIR      = CONFIG_DIR / "mcp"
end

ClaudePersona::CLI.run(ARGV)
