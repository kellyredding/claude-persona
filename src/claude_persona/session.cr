require "json"

module ClaudePersona
  class Session
    getter persona_name : String
    getter config : PersonaConfig
    getter start_time : Time
    getter end_time : Time?
    getter resume_session_id : String?
    getter vibe : Bool

    def initialize(@persona_name : String, @config : PersonaConfig, @resume_session_id : String? = nil, @vibe : Bool = false)
      @start_time = Time.utc
    end

    def run : Int32
      args = CommandBuilder.new(@config, @resume_session_id, @vibe).build

      display_launch_info

      # Run Claude interactively
      status = Process.run("claude",
        args: args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      @end_time = Time.utc

      # Display session summary
      display_summary

      status.exit_code
    end

    private def display_summary
      return unless end_time = @end_time

      duration = end_time - @start_time

      puts ""
      puts "=================================================="
      puts "🏁 Claude Persona Summary"
      puts "=================================================="
      puts "Persona:  #{@persona_name}"
      puts "Model:    #{@config.model}"
      puts "Runtime:  #{format_duration(duration)}"

      # Try to calculate cost from session files
      if cost_info = calculate_session_cost
        puts "Cost:     $#{sprintf("%.4f", cost_info[:cost])}"
        if session_id = cost_info[:session_id]
          puts "Session:  #{session_id}"
          puts ""
          vibe_flag = @vibe ? " --vibe" : ""
          puts "Resume:   claude-persona #{@persona_name} --resume #{session_id}#{vibe_flag}"
        end
      end

      puts "=================================================="
    end

    private def display_launch_info
      if session_id = @resume_session_id
        puts "🔄 Resuming persona: #{@persona_name} (session #{session_id[0, 8]}...)"
      else
        puts "🚀 Launching persona: #{@persona_name}"
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
        puts "   😎 Vibe mode"
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

    private def calculate_session_cost : NamedTuple(cost: Float64, session_id: String?)?
      # Find the most recent session JSONL file
      projects_dir = Path.home / ".claude" / "projects"
      return nil unless Dir.exists?(projects_dir)

      # Get the current working directory's project folder
      # Must resolve symlinks first (e.g., /tmp -> /private/tmp on macOS)
      real_cwd = File.realpath(Dir.current)
      cwd_encoded = real_cwd.gsub("/", "-").lstrip('-')
      project_dir = projects_dir / cwd_encoded
      return nil unless Dir.exists?(project_dir)

      # Find most recent .jsonl file modified during our session
      # Filter out agent-*.jsonl files (sub-agent sessions)
      session_file = Dir.children(project_dir)
        .select { |f| f.ends_with?(".jsonl") && !f.starts_with?("agent-") }
        .map { |f| project_dir / f }
        .select { |p| File.info(p).modification_time >= @start_time }
        .max_by? { |p| File.info(p).modification_time }

      return nil unless session_file

      # Extract session ID from filename (UUID.jsonl)
      session_id = File.basename(session_file.to_s, ".jsonl")

      # Parse JSONL and sum token costs
      cost = calculate_cost_from_jsonl(session_file)

      {cost: cost, session_id: session_id}
    end

    private def calculate_cost_from_jsonl(path : Path) : Float64
      total_cost = 0.0

      # Model pricing per million tokens (as of Jan 2025)
      # TODO: Periodically check https://www.anthropic.com/pricing for updates
      pricing = {
        "opus" => {
          "input"       => 15.0,
          "output"      => 75.0,
          "cache_write" => 18.75,
          "cache_read"  => 1.50,
        },
        "sonnet" => {
          "input"       => 3.0,
          "output"      => 15.0,
          "cache_write" => 3.75,
          "cache_read"  => 0.30,
        },
        "haiku" => {
          "input"       => 0.25,
          "output"      => 1.25,
          "cache_write" => 0.30,
          "cache_read"  => 0.03,
        },
      }

      model_key = case @config.model.downcase
                  when /opus/  then "opus"
                  when /haiku/ then "haiku"
                  else              "sonnet"
                  end

      prices = pricing[model_key]

      File.each_line(path) do |line|
        begin
          json = JSON.parse(line)

          if message = json["message"]?
            if usage = message["usage"]?
              input = (usage["input_tokens"]?.try(&.as_i?) || 0).to_f64
              output = (usage["output_tokens"]?.try(&.as_i?) || 0).to_f64
              cache_write = (usage["cache_creation_input_tokens"]?.try(&.as_i?) || 0).to_f64
              cache_read = (usage["cache_read_input_tokens"]?.try(&.as_i?) || 0).to_f64

              # Calculate cost (pricing is per million tokens)
              total_cost += (input / 1_000_000.0) * prices["input"]
              total_cost += (output / 1_000_000.0) * prices["output"]
              total_cost += (cache_write / 1_000_000.0) * prices["cache_write"]
              total_cost += (cache_read / 1_000_000.0) * prices["cache_read"]
            end
          end
        rescue
          # Skip malformed lines
        end
      end

      total_cost
    end
  end
end
