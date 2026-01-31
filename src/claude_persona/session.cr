require "json"
require "uuid"

module ClaudePersona
  class Session
    PRICING_URL = "https://raw.githubusercontent.com/kellyredding/claude-persona/main/config/pricing.json"

    getter persona_name : String
    getter config : PersonaConfig
    getter start_time : Time
    getter end_time : Time?
    getter resume_session_id : String?
    getter session_id : String
    getter vibe : Bool
    getter pricing_error : String?

    def initialize(@persona_name : String, @config : PersonaConfig, @resume_session_id : String? = nil, @vibe : Bool = false)
      @start_time = Time.local
      # Use resume session ID if resuming, otherwise generate new UUID
      @session_id = @resume_session_id || UUID.random.to_s
      @pricing_error = nil
    end

    def run : Int32
      args = CommandBuilder.new(@config, @resume_session_id, @session_id, @vibe).build

      display_launch_info

      # Run Claude interactively
      status = Process.run("claude",
        args: args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      @end_time = Time.local

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

      # Calculate cost from session file (round up to nearest cent)
      cost = calculate_session_cost
      if cost
        rounded_cost = (cost * 100).ceil / 100.0
        puts "Cost:     $#{sprintf("%.2f", rounded_cost)}"
      else
        puts "Cost:     (unavailable - #{@pricing_error})"
      end
      puts "Session:  #{@session_id}"
      puts ""
      vibe_flag = @vibe ? " --vibe" : ""
      puts "Resume:   claude-persona #{@persona_name} --resume #{@session_id}#{vibe_flag}"

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

      # Display auto-start indicator
      if prompt = @config.prompt
        unless prompt.initial_message.empty?
          puts "   💬 Auto-start enabled"
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

    private def calculate_session_cost : Float64?
      # Find the session JSONL file using our known session ID
      projects_dir = Path.home / ".claude" / "projects"
      return 0.0 unless Dir.exists?(projects_dir)

      # Get the current working directory's project folder
      # Must resolve symlinks first (e.g., /tmp -> /private/tmp on macOS)
      # Claude encodes paths by replacing / and . with - (keeping leading dash)
      real_cwd = File.realpath(Dir.current)
      cwd_encoded = real_cwd.gsub(/[\/.]/, "-")
      project_dir = projects_dir / cwd_encoded
      return 0.0 unless Dir.exists?(project_dir)

      # Look for the session file with our known session ID
      session_file = project_dir / "#{@session_id}.jsonl"
      return 0.0 unless File.exists?(session_file)

      # Fetch pricing from GitHub
      pricing = fetch_pricing
      return nil unless pricing

      # Parse JSONL and sum token costs
      calculate_cost_from_jsonl(session_file, pricing)
    end

    private def fetch_pricing : Hash(String, Hash(String, Float64))?
      # Check for curl first
      unless command_exists?("curl")
        @pricing_error = "curl not installed"
        return nil
      end

      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(
        "curl",
        args: ["-fsSL", "--max-time", "5", PRICING_URL],
        output: output,
        error: error
      )

      unless status.success?
        @pricing_error = "couldn't fetch pricing"
        return nil
      end

      parse_pricing(output.to_s)
    end

    private def parse_pricing(json_str : String) : Hash(String, Hash(String, Float64))?
      json = JSON.parse(json_str)
      models = json["models"]?
      return set_pricing_error("invalid pricing format") unless models

      result = {} of String => Hash(String, Float64)

      ["opus", "sonnet", "haiku"].each do |model|
        model_data = models[model]?
        return set_pricing_error("missing #{model} pricing") unless model_data

        prices = {} of String => Float64
        ["input", "output", "cache_write", "cache_read"].each do |key|
          value = model_data[key]?
          return set_pricing_error("missing #{model}.#{key}") unless value
          prices[key] = value.as_f
        end
        result[model] = prices
      end

      result
    rescue ex
      set_pricing_error("couldn't parse pricing")
    end

    private def set_pricing_error(msg : String) : Nil
      @pricing_error = msg
      nil
    end

    private def command_exists?(cmd : String) : Bool
      Process.run("which", args: [cmd], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    end

    private def calculate_cost_from_jsonl(path : Path, pricing : Hash(String, Hash(String, Float64))) : Float64
      total_cost = 0.0

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
