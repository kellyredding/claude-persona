require "json"

module ClaudePersona
  module SessionSettings
    # Passed inline to `claude --settings` rather than as a file: claude-persona
    # replaces itself with claude, so nothing is left to delete a file after.
    def self.json(session_id : String) : String
      {"env" => {"CLAUDE_CLI_SESSION_ID" => session_id}}.to_json
    end
  end
end
