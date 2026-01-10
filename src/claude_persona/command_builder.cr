module ClaudePersona
  class CommandBuilder
    getter args : Array(String)

    def initialize(@config : PersonaConfig, @resume_session_id : String? = nil, @vibe : Bool = false)
      @args = [] of String
    end

    def build : Array(String)
      add_resume
      add_model
      add_system_prompt
      add_directories
      add_tools
      add_mcp_configs
      add_permission_mode
      add_vibe_mode

      @args
    end

    private def add_resume
      if session_id = @resume_session_id
        @args << "--resume" << session_id
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

    # Format command for dryrun output
    def format_command : String
      build if @args.empty?

      lines = ["# claude-persona v#{VERSION}", "claude \\"]

      # Group args into flag + value(s) for readable output
      i = 0
      while i < @args.size
        arg = @args[i]
        if arg.starts_with?("--")
          # Collect all values until next flag
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

      # Remove trailing backslash from last line
      lines[-1] = lines[-1].rchop(" \\")

      lines.join("\n")
    end
  end
end
