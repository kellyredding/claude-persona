require "uuid"

module ClaudePersona
  class Session
    getter persona_name : String
    getter config : PersonaConfig
    getter start_time : Time
    getter end_time : Time?
    getter resume_session_id : String?
    getter session_id : String
    getter vibe : Bool
    getter settings_path : String?
    getter session_id_path : String?

    def initialize(@persona_name : String, @config : PersonaConfig, @resume_session_id : String? = nil, @vibe : Bool = false, cli_session_id : String? = nil)
      @start_time = Time.local
      # Priority: resume ID > CLI-injected ID > generate new UUID
      @session_id = @resume_session_id || cli_session_id || UUID.random.to_s
    end

    def run : Int32
      # Create session tracking hook
      @settings_path, @session_id_path =
        SessionHookSettings.create(@session_id)

      args = CommandBuilder.new(
        @config,
        session_id: @session_id,
        resuming: !@resume_session_id.nil?,
        vibe: @vibe,
        settings_path: @settings_path,
      ).build

      display_launch_info

      # Run Claude interactively
      status = Process.run("claude",
        args: args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      @end_time = Time.local

      # Read latest session ID (may have changed via /clear or compaction)
      if path = @session_id_path
        if tracked_id = SessionHookSettings.read_session_id(path)
          @session_id = tracked_id
        end
      end

      # Display session summary
      display_summary

      # Clean up temp files
      SessionHookSettings.cleanup(@settings_path, @session_id_path)

      status.exit_code
    end

    private def display_summary
      return unless end_time = @end_time

      duration = end_time - @start_time

      puts ""
      puts "=================================================="
      puts "\u{1F3C1} Claude Persona Summary"
      puts "=================================================="
      puts "Persona:  #{@persona_name}"
      puts "Model:    #{@config.model}"
      puts "Runtime:  #{format_duration(duration)}"
      puts "Session:  #{@session_id}"
      puts ""
      vibe_flag = @vibe ? " --vibe" : ""
      puts "Resume:   claude-persona #{@persona_name} --resume #{@session_id}#{vibe_flag}"

      puts "=================================================="
    end

    private def display_launch_info
      if session_id = @resume_session_id
        puts "\u{1F504} Resuming persona: #{@persona_name} (session #{session_id[0, 8]}...)"
      else
        puts "\u{1F680} Launching persona: #{@persona_name} (session #{@session_id[0, 8]}...)"
      end

      puts "   Model: #{@config.model}"

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

    private def format_duration(duration : Time::Span) : String
      total_seconds = duration.total_seconds.to_i
      hours = total_seconds // 3600
      minutes = (total_seconds % 3600) // 60
      seconds = total_seconds % 60

      if hours > 0
        "#{hours}h #{minutes}m #{seconds}s"
      elsif minutes > 0
        "#{minutes}m #{seconds}s"
      else
        "#{seconds}s"
      end
    end
  end
end
