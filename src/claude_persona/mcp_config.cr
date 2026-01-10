require "json"

module ClaudePersona
  module McpHandler
    # Resolve MCP config names to full file paths
    def self.resolve_mcp_paths(config_names : Array(String)) : Array(String)
      config_names.map do |name|
        path = MCP_DIR / "#{name}.json"
        unless File.exists?(path)
          raise ConfigError.new("MCP config '#{name}' not found at #{path}")
        end
        path.to_s
      end
    end

    # List available MCP configs
    def self.list : Array(String)
      return [] of String unless Dir.exists?(MCP_DIR)

      Dir.children(MCP_DIR)
        .select { |f| f.ends_with?(".json") }
        .map { |f| f.chomp(".json") }
        .sort
    end

    # Export MCP config from Claude
    def self.export(name : String) : Bool
      # Run claude mcp get to check if it exists
      output = `claude mcp get #{name} 2>&1`

      unless $?.success?
        STDERR.puts "Error: MCP '#{name}' not found in Claude config"
        return false
      end

      # Parse the output to extract config
      config = parse_claude_mcp_output(name, output)

      # Ensure directory exists
      Dir.mkdir_p(MCP_DIR)

      # Write JSON file
      path = MCP_DIR / "#{name}.json"
      File.write(path, config.to_pretty_json)

      puts "Exported to #{path}"
      true
    end

    # Parse claude mcp get output into JSON structure
    # NOTE: This parsing depends on the text output format of `claude mcp get`.
    # If Claude CLI changes its output format, this may need to be updated.
    # A future version of Claude CLI may support `--json` output which would be more reliable.
    private def self.parse_claude_mcp_output(name : String, output : String) : Hash(String, JSON::Any)
      lines = output.lines.map(&.strip)

      type = ""
      url = ""
      command = ""
      args = [] of String
      env = {} of String => String
      in_env_section = false

      lines.each do |line|
        # Check if we're entering or in the Env section
        if line =~ /^Env:\s*$/i
          in_env_section = true
          next
        end

        # If in env section, parse key=value or key: value pairs (indented)
        if in_env_section
          if line =~ /^\s+(\w+)[=:]\s*(.+)$/
            env[$1] = $2
            next
          elsif line =~ /^[A-Z]/i && !line.starts_with?(" ")
            # Non-indented line starting with letter = new section, exit env parsing
            in_env_section = false
          end
        end

        case line
        when /^Type:\s*(\w+)/i
          type = $1.downcase
        when /^URL:\s*(.+)/i
          url = $1
        when /^Command:\s*(.+)/i
          command = $1
        when /^Args:\s*(.+)/i
          args = $1.split(/\s+/)
        when /^Env:\s+(\w+)[=:]\s*(.+)$/i
          # Single-line env format: Env: KEY=value
          env[$1] = $2
        end
      end

      server_config = {} of String => JSON::Any
      server_config["type"] = JSON::Any.new(type)

      case type
      when "http", "sse"
        server_config["url"] = JSON::Any.new(url)
      when "stdio"
        server_config["command"] = JSON::Any.new(command)
        server_config["args"] = JSON::Any.new(args.map { |a| JSON::Any.new(a) })
        unless env.empty?
          env_json = {} of String => JSON::Any
          env.each { |k, v| env_json[k] = JSON::Any.new(v) }
          server_config["env"] = JSON::Any.new(env_json)
        end
      end

      {
        "mcpServers" => JSON::Any.new({
          name => JSON::Any.new(server_config),
        }),
      }
    end

    # Export all MCPs from Claude
    def self.export_all : Int32
      output = `claude mcp list 2>&1`

      # Parse server names from output
      names = output.lines
        .select { |l| l.includes?(":") && !l.starts_with?("Checking") }
        .map { |l| l.split(":").first.strip }

      exported = 0
      names.each do |name|
        if export(name)
          exported += 1
        end
      end

      exported
    end
  end
end
