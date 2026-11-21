require "json"

module ClaudePersona
  module SessionSettings
    # Passed inline to `claude --settings` rather than as a file: claude-persona
    # replaces itself with claude, so nothing is left to delete a file after.
    #
    # A host's settings are merged underneath, so its hooks and env survive
    # while the session id is always the one this launch uses.
    def self.json(session_id : String, host : String? = nil) : String
      own = {"env" => JSON::Any.new({"CLAUDE_CLI_SESSION_ID" => JSON::Any.new(session_id)})}
      deep_merge(parse(host), own).to_json
    end

    # A host's settings alone, for a launch that carries no session id.
    def self.host_json(host : String?) : String?
      host.try { |source| parse(source).to_json }
    end

    private def self.parse(source : String?) : Hash(String, JSON::Any)
      return {} of String => JSON::Any unless source

      JSON.parse(source).as_h? || raise InvalidSettingsError.new("got #{source.strip[0, 40]}")
    rescue e : JSON::ParseException
      raise InvalidSettingsError.new(e.message || "invalid JSON")
    end

    private def self.deep_merge(
      base : Hash(String, JSON::Any),
      overlay : Hash(String, JSON::Any),
    ) : Hash(String, JSON::Any)
      result = base.dup
      overlay.each do |key, value|
        left = result[key]?.try(&.as_h?)
        right = value.as_h?
        result[key] = left && right ? JSON::Any.new(deep_merge(left, right)) : value
      end
      result
    end
  end
end
