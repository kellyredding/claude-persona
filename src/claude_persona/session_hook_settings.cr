require "json"

module ClaudePersona
  module SessionHookSettings
    # Create temp settings file with SessionStart hook
    # Returns {settings_path, session_id_path}
    def self.create(session_id : String) : Tuple(String, String)
      session_id_path = File.tempname("claude-persona-session", ".id")
      settings_path = File.tempname("claude-persona-settings", ".json")

      # Write initial session ID so it's available even if hook
      # never fires (e.g., session exits before any reset)
      File.write(session_id_path, session_id)

      hook_command = "claude-persona track-session #{session_id_path}"

      settings = {
        "hooks" => {
          "SessionStart" => [
            {
              "hooks" => [
                {
                  "type"    => "command",
                  "command" => hook_command,
                },
              ],
            },
          ],
        },
      }

      File.write(settings_path, settings.to_json)

      {settings_path, session_id_path}
    end

    # Read the latest session ID from the tracking file
    def self.read_session_id(session_id_path : String) : String?
      return nil unless File.exists?(session_id_path)

      content = File.read(session_id_path).strip
      content.empty? ? nil : content
    end

    # Pretty-printed example of the settings JSON structure
    def self.example_settings_json : String
      JSON.build(indent: "  ") do |json|
        json.object do
          json.field "hooks" do
            json.object do
              json.field "SessionStart" do
                json.array do
                  json.object do
                    json.field "hooks" do
                      json.array do
                        json.object do
                          json.field "type", "command"
                          json.field "command", "claude-persona track-session <output-file>"
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Clean up temp files (accepts nil for either path)
    def self.cleanup(settings_path : String?, session_id_path : String?)
      File.delete(settings_path) if settings_path && File.exists?(settings_path)
      File.delete(session_id_path) if session_id_path && File.exists?(session_id_path)
    end
  end
end
