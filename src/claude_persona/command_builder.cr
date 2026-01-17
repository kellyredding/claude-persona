module ClaudePersona
  class CommandBuilder
    getter args : Array(String)
    getter initial_message : String?

    def initialize(
      @config : PersonaConfig,
      resume_session_id : String? = nil,
      session_id : String? = nil,
      vibe : Bool = false,
      initial_message : String? = nil,
    )
      @resume_session_id = resume_session_id
      @session_id = session_id
      @vibe = vibe
      @args = [] of String

      # Use provided initial_message, or fall back to config's initial_message
      # Skip config's initial_message when resuming (session already started)
      @initial_message = initial_message || (resume_session_id ? nil : @config.prompt.try(&.initial_message).try { |m| m.empty? ? nil : m })
    end

    def build : Array(String)
      add_resume_or_session
      add_model
      add_system_prompt
      add_directories
      add_tools
      add_mcp_configs
      add_permission_mode
      add_vibe_mode
      add_initial_message

      @args
    end

    private def add_resume_or_session
      if session_id = @resume_session_id
        @args << "--resume" << session_id
      elsif session_id = @session_id
        @args << "--session-id" << session_id
      end
    end

    private def add_model
      @args << "--model" << @config.model
    end

    private def add_system_prompt
      if prompt = @config.prompt
        unless prompt.system.empty?
          @args << "--system-prompt" << prompt.system
        end
      end
    end

    private def add_directories
      if dirs = @config.directories
        dirs.allowed.each do |dir|
          expanded = Path[dir].expand(home: true).to_s
          @args << "--add-dir" << expanded
        end
      end
    end

    private def add_tools
      if tools = @config.tools
        unless tools.allowed.empty?
          @args << "--allowed-tools"
          @args.concat(tools.allowed)
        end

        unless tools.disallowed.empty?
          @args << "--disallowed-tools"
          @args.concat(tools.disallowed)
        end
      end
    end

    private def add_mcp_configs
      if mcp = @config.mcp
        unless mcp.configs.empty?
          @args << "--strict-mcp-config"

          paths = McpHandler.resolve_mcp_paths(mcp.configs)
          paths.each do |path|
            @args << "--mcp-config" << path
          end
        end
      end
    end

    private def add_permission_mode
      if perms = @config.permissions
        @args << "--permission-mode" << perms.mode
      end
    end

    private def add_vibe_mode
      if @vibe
        @args << "--dangerously-skip-permissions"
      end
    end

    private def add_initial_message
      if msg = @initial_message
        @args << "--" << msg
      end
    end

    # Format command for dryrun output
    def format_command : String
      build if @args.empty?

      lines = ["# claude-persona v#{VERSION}", "claude \\"]

      # Group args into flag + value(s) for readable output
      i = 0
      while i < @args.size
        arg = @args[i]

        # Skip the -- separator and initial_message (handled separately)
        if arg == "--"
          break
        end

        if arg.starts_with?("--")
          # Collect all values until next flag or end of flags
          values = [] of String
          j = i + 1
          while j < @args.size && !@args[j].starts_with?("--")
            values << @args[j]
            j += 1
          end

          if values.empty?
            # Flag with no value (e.g., --dangerously-skip-permissions)
            lines << "  #{arg} \\"
          elsif values.size == 1
            # Single value - may need truncation or quoting
            value = values.first
            display_value = if value.size > 60
                              "\"#{value[0, 57]}...\""
                            else
                              value.includes?(" ") || value.includes?("(") ? "\"#{value}\"" : value
                            end
            lines << "  #{arg} #{display_value} \\"
          else
            # Multiple values (e.g., --allowed-tools Read Write Edit)
            quoted_values = values.map do |v|
              v.includes?(" ") || v.includes?("(") ? "\"#{v}\"" : v
            end
            lines << "  #{arg} #{quoted_values.join(" ")} \\"
          end

          i = j
        else
          i += 1
        end
      end

      # Add initial_message with -- separator if present
      if msg = @initial_message
        display_msg = if msg.size > 60
                        "\"#{msg[0, 57]}...\""
                      else
                        "\"#{msg}\""
                      end
        lines << "  -- #{display_msg}"
      else
        # Remove trailing backslash from last line when no initial_message
        lines[-1] = lines[-1].rchop(" \\")
      end

      lines.join("\n")
    end
  end
end
