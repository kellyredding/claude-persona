require "uuid"

module ClaudePersona
  class Session
    getter persona_name : String
    getter config : PersonaConfig
    getter resume_session_id : String?
    getter session_id : String
    getter vibe : Bool

    def initialize(@persona_name : String, @config : PersonaConfig, @resume_session_id : String? = nil, @vibe : Bool = false, cli_session_id : String? = nil)
      # Priority: resume ID > CLI-injected ID > generate new UUID
      @session_id = @resume_session_id || cli_session_id || UUID.random.to_s
    end

    def run : NoReturn
      args = CommandBuilder.new(
        @config,
        session_id: @session_id,
        resuming: !@resume_session_id.nil?,
        vibe: @vibe,
        settings: SessionSettings.json(@session_id),
      ).build

      display_launch_info

      ClaudeExec.exec(args)
    end

    private def display_launch_info
      if session_id = @resume_session_id
        puts "\u{1F504} Resuming persona: #{@persona_name} (session #{session_id[0, 8]}...)"
      else
        puts "\u{1F680} Launching persona: #{@persona_name} (session #{@session_id[0, 8]}...)"
      end

      puts "   Model: #{@config.model}"
      if effort = @config.effort
        puts "   Effort: #{effort}"
      end

      # Display directories
      if dirs = @config.directories
        unless dirs.allowed.empty?
          if dirs.allowed.size == 1
            expanded = Path[dirs.allowed.first].expand(home: true)
            puts "   Directory: #{expanded}"
          else
            puts "   Directories:"
            dirs.allowed.each do |dir|
              expanded = Path[dir].expand(home: true)
              puts "     - #{expanded}"
            end
          end
        end
      end

      # Display MCPs
      if mcp = @config.mcp
        unless mcp.configs.empty?
          puts "   MCPs: #{mcp.configs.join(", ")}"
        end
      end

      # Display allowed tools
      if tools = @config.tools
        unless tools.allowed.empty?
          puts "   Allowed tools: #{tools.allowed.join(", ")}"
        end
        unless tools.disallowed.empty?
          puts "   Disallowed tools: #{tools.disallowed.join(", ")}"
        end
      end

      # Display permission mode
      if perms = @config.permissions
        puts "   Permission mode: #{perms.mode}"
      end

      # Display vibe mode
      if @vibe
        puts "   \u{1F60E} Vibe mode"
      end

      # Display auto-start indicator
      if prompt = @config.prompt
        unless prompt.initial_message.empty?
          puts "   \u{1F4AC} Auto-start enabled"
        end
      end

      puts ""
    end
  end
end
