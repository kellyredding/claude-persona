require "json"

module ClaudePersona
  module McpHandler
    # Claude config file paths (with env var overrides for testing)
    CLAUDE_USER_CONFIG_PATH = Path.new(
      ENV.fetch("CLAUDE_USER_CONFIG_PATH", (Path.home / ".claude.json").to_s)
    )
    CLAUDE_PROJECT_CONFIG_PATH = Path.new(
      ENV.fetch("CLAUDE_PROJECT_CONFIG_PATH", (Path[Dir.current] / ".claude.json").to_s)
    )

    # Resolve MCP config names to full file paths (for imported configs)
    def self.resolve_mcp_paths(config_names : Array(String)) : Array(String)
      config_names.map do |name|
        path = MCP_DIR / "#{name}.json"
        unless File.exists?(path)
          raise McpConfigNotFound.new(name, path)
        end
        path.to_s
      end
    end

    # List imported MCP configs (in claude-persona's mcp directory)
    def self.list : Array(String)
      return [] of String unless Dir.exists?(MCP_DIR)

      Dir.children(MCP_DIR)
        .select { |f| f.ends_with?(".json") }
        .map { |f| f.chomp(".json") }
        .sort
    end

    # Get available MCPs from user-scope Claude config
    def self.available_user_mcps : Hash(String, JSON::Any)
      read_mcp_servers_from_file(CLAUDE_USER_CONFIG_PATH)
    end

    # Get available MCPs from project-scope Claude config
    def self.available_project_mcps : Hash(String, JSON::Any)
      read_mcp_servers_from_file(CLAUDE_PROJECT_CONFIG_PATH)
    end

    # Read mcpServers from a Claude config file
    private def self.read_mcp_servers_from_file(path : Path) : Hash(String, JSON::Any)
      return {} of String => JSON::Any unless File.exists?(path)

      begin
        data = JSON.parse(File.read(path))
        if servers = data["mcpServers"]?
          result = {} of String => JSON::Any
          servers.as_h.each { |k, v| result[k] = v }
          result
        else
          {} of String => JSON::Any
        end
      rescue
        {} of String => JSON::Any
      end
    end

    # Display available MCPs from both scopes
    def self.display_available
      user_mcps = available_user_mcps
      project_mcps = available_project_mcps

      puts "Available MCP servers to import:"
      puts ""

      # User scope
      puts "User scope (#{CLAUDE_USER_CONFIG_PATH}):"
      if user_mcps.empty?
        puts "  (none available)"
      else
        user_mcps.each do |name, config|
          type = config["type"]?.try(&.as_s) || "unknown"
          puts "  #{name} (#{type})"
        end
      end

      puts ""

      # Project scope
      puts "Project scope (#{CLAUDE_PROJECT_CONFIG_PATH}):"
      if project_mcps.empty?
        puts "  (none available)"
      else
        project_mcps.each do |name, config|
          type = config["type"]?.try(&.as_s) || "unknown"
          puts "  #{name} (#{type})"
        end
      end
    end

    # Import MCP config from Claude config files
    def self.import(name : String) : Bool
      # Check user scope first, then project scope
      user_mcps = available_user_mcps
      project_mcps = available_project_mcps

      mcp_config = user_mcps[name]? || project_mcps[name]?

      unless mcp_config
        STDERR.puts "Error: MCP '#{name}' not found in Claude config"
        STDERR.puts ""
        display_available
        return false
      end

      # Build the import structure
      import_data = {
        "mcpServers" => JSON::Any.new({
          name => mcp_config,
        }),
      }

      # Ensure directory exists
      Dir.mkdir_p(MCP_DIR)

      # Write JSON file
      path = MCP_DIR / "#{name}.json"
      File.write(path, import_data.to_pretty_json)

      type = mcp_config["type"]?.try(&.as_s) || "unknown"
      puts "Imported #{name} (#{type}) to #{path}"
      true
    end

    # Import all MCPs from Claude config files
    def self.import_all : Int32
      user_mcps = available_user_mcps
      project_mcps = available_project_mcps

      # Merge, with user scope taking precedence
      all_mcps = project_mcps.merge(user_mcps)

      if all_mcps.empty?
        puts "No MCP servers found in Claude config."
        return 0
      end

      imported = 0
      all_mcps.each_key do |name|
        if import(name)
          imported += 1
        end
      end

      imported
    end
  end
end
