# Explicit and first: the glob below loads alphabetically, which would reach
# the classes descending from Error before Error itself exists. A superclass
# has to be defined at the point its subclass is compiled.
require "./claude_persona/error"
require "./claude_persona/*"

module ClaudePersona
  VERSION = {{ read_file("#{__DIR__}/../VERSION.txt").strip }}

  # Allow override via environment variable for testing
  CONFIG_DIR   = Path.new(ENV.fetch("CLAUDE_PERSONA_CONFIG_DIR", (Path.home / ".claude-persona").to_s))
  PERSONAS_DIR = CONFIG_DIR / "personas"
  MCP_DIR      = CONFIG_DIR / "mcp"
end

# Reach the library without also running the program. Specs require this file
# for its types; integration examples invoke the built binary as a subprocess
# instead, where exit codes and stream handling are actually observable.
unless ENV.has_key?("CLAUDE_PERSONA_SKIP_CLI")
  ClaudePersona::CLI.run(ARGV)
end
