require "json"

module ClaudePersona
  # A persona as a host program reads it: `show --json`. Hosts launch personas
  # through claude-persona and need to know, before launching, what the launch
  # will do, above all whether it submits an opening message.
  module PersonaReport
    def self.json(name : String, config : PersonaConfig) : String
      JSON.build do |json|
        json.object do
          json.field "name", name
          json.field "version", config.version
          json.field "description", config.description
          json.field "model", config.model
          json.field "effort", config.effort
          json.field "directories", config.directories.try(&.allowed) || [] of String
          json.field "mcp_configs", config.mcp.try(&.configs) || [] of String
          json.field "tools" do
            json.object do
              json.field "allowed", config.tools.try(&.allowed) || [] of String
              json.field "disallowed", config.tools.try(&.disallowed) || [] of String
            end
          end
          json.field "permission_mode", config.permissions.try(&.mode)
          json.field "system_prompt", present(config.prompt.try(&.system))
          # Null exactly when a fresh launch submits no opening message, the
          # same test CommandBuilder applies.
          json.field "initial_message", present(config.prompt.try(&.initial_message))
        end
      end
    end

    private def self.present(text : String?) : String?
      text.try { |t| t.empty? ? nil : t }
    end
  end
end
