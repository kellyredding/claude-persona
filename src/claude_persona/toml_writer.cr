module ClaudePersona
  module TomlWriter
    # Serialize PersonaConfig to TOML string with controlled field order
    def self.to_toml(config : PersonaConfig, version_override : String? = nil) : String
      lines = [] of String

      # Always write version first
      version = version_override || config.version || VERSION
      lines << "version = #{quote(version)}"

      # Description (if present)
      unless config.description.empty?
        lines << "description = #{quote(config.description)}"
      end

      # Model
      lines << "model = #{quote(config.model)}"

      # Directories section
      if dirs = config.directories
        unless dirs.allowed.empty?
          lines << ""
          lines << "[directories]"
          lines << "allowed = ["
          dirs.allowed.each { |d| lines << "  #{quote(d)}," }
          lines << "]"
        end
      end

      # MCP section
      if mcp = config.mcp
        unless mcp.configs.empty?
          lines << ""
          lines << "[mcp]"
          lines << "configs = [#{mcp.configs.map { |c| quote(c) }.join(", ")}]"
        end
      end

      # Tools section
      if tools = config.tools
        if !tools.allowed.empty? || !tools.disallowed.empty?
          lines << ""
          lines << "[tools]"
          unless tools.allowed.empty?
            lines << "allowed = [#{tools.allowed.map { |t| quote(t) }.join(", ")}]"
          end
          unless tools.disallowed.empty?
            lines << "disallowed = [#{tools.disallowed.map { |t| quote(t) }.join(", ")}]"
          end
        end
      end

      # Permissions section
      if perms = config.permissions
        lines << ""
        lines << "[permissions]"
        lines << "mode = #{quote(perms.mode)}"
      end

      # Prompt section
      if prompt = config.prompt
        if !prompt.system.empty? || !prompt.initial_message.empty?
          lines << ""
          lines << "[prompt]"
          unless prompt.system.empty?
            if prompt.system.includes?("\n")
              # Use literal strings (''') to avoid toml.cr bug with embedded quotes in basic strings
              lines << "system = '''"
              lines << prompt.system
              lines << "'''"
            else
              lines << "system = #{quote(prompt.system)}"
            end
          end
          unless prompt.initial_message.empty?
            if prompt.initial_message.includes?("\n")
              # Use literal strings (''') to avoid toml.cr bug with embedded quotes in basic strings
              lines << "initial_message = '''"
              lines << prompt.initial_message
              lines << "'''"
            else
              lines << "initial_message = #{quote(prompt.initial_message)}"
            end
          end
        end
      end

      lines.join("\n") + "\n"
    end

    # Write config to file path
    def self.write(path : Path, config : PersonaConfig, version_override : String? = nil)
      File.write(path, to_toml(config, version_override))
    end

    private def self.quote(s : String) : String
      # Simple quoting - escape backslashes and quotes
      "\"#{s.gsub("\\", "\\\\").gsub("\"", "\\\"")}\""
    end
  end
end
