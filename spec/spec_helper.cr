require "spec"

# Set up test fixtures directory via environment variable
# This must be set BEFORE requiring claude_persona so CONFIG_DIR picks it up
SPEC_FIXTURES = Path[__DIR__] / "fixtures"
ENV["CLAUDE_PERSONA_CONFIG_DIR"] = SPEC_FIXTURES.to_s

require "../src/claude_persona"
