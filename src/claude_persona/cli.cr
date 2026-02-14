require "option_parser"

module ClaudePersona
  class CLI
    # Subcommand names that cannot be used as persona names
    RESERVED_NAMES = %w[list generate show rename remove mcp update help version]

    # Model used for the persona generator
    GENERATOR_MODEL = "opus"

    def self.run(args : Array(String))
      # Flag state
      vibe = false
      dryrun = false
      resume_id : String? = nil
      print_prompt : String? = nil
      output_format : String? = nil
      show_help_flag = false
      show_version_flag = false

      # Parse flags (position-independent)
      parser = OptionParser.new do |p|
        p.banner = build_banner

        p.separator ""
        p.separator "Options:"

        p.on("--vibe", "Skip all permission checks") { vibe = true }
        p.on("--dangerously-skip-permissions", "Alias for --vibe") { vibe = true }
        p.on("--dry-run", "Show command without executing") { dryrun = true }
        p.on("-p PROMPT", "--print=PROMPT", "Print response and exit (non-interactive)") { |prompt| print_prompt = prompt }
        p.on("--output-format=FORMAT", "Output format: text, json, stream-json (use with -p)") { |fmt| output_format = fmt }
        p.on("-r ID", "--resume=ID", "Resume a previous session") { |id| resume_id = id }
        p.on("-h", "--help", "Show this help") { show_help_flag = true }
        p.on("-v", "--version", "Show version") { show_version_flag = true }

        p.invalid_option do |flag|
          STDERR.puts "Error: Unknown flag '#{flag}'"
          STDERR.puts "Run 'claude-persona --help' for usage"
          exit(1)
        end
      end

      # Parse and collect positional args
      positional_args = [] of String
      parser.unknown_args { |args| positional_args = args }
      parser.parse(args)

      # Handle help/version flags
      if show_help_flag
        puts parser
        return
      end

      if show_version_flag
        puts VERSION
        return
      end

      # No args means show help
      if positional_args.empty?
        puts parser
        return
      end

      # First positional arg is command or persona
      command = positional_args.first
      rest = positional_args[1..]? || [] of String

      case command
      when "list"
        list_personas
      when "generate"
        generate_persona(dryrun)
      when "show"
        show_persona(rest.first?)
      when "rename"
        rename_persona(rest[0]?, rest[1]?)
      when "remove"
        remove_persona(rest.first?)
      when "mcp"
        handle_mcp_command(rest)
      when "update"
        handle_update_command(rest)
      when "help"
        puts parser
      when "version"
        puts VERSION
      else
        # Assume it's a persona name, validate and launch
        validate_and_launch_persona(command, resume_id, vibe, dryrun, print_prompt, output_format)
      end
    end

    private def self.build_banner : String
      <<-BANNER
      Usage: claude-persona [persona|command] [options]

      Launch a persona:
        claude-persona <persona>              Launch Claude with persona
        claude-persona <persona> --resume ID  Resume a session
        claude-persona <persona> -p "prompt"  One-shot: print response and exit

      Commands:
        list                    List available personas
        generate                Create new persona interactively
        show <persona>          Display persona configuration
        rename <old> <new>      Rename a persona
        remove <persona>        Delete a persona
        update                  Update to latest version
        update preview          Preview update without changes
        update force            Reinstall latest version
        mcp available           List MCPs available to import
        mcp list                List imported MCP configs
        mcp import <name>       Import MCP config from Claude
        mcp import-all          Import all MCPs from Claude
        mcp show <name>         Display imported MCP config
        mcp remove <name>       Delete imported MCP config
        help                    Show this help
        version                 Show version
      BANNER
    end

    private def self.validate_and_launch_persona(
      name : String,
      resume_id : String?,
      vibe : Bool,
      dryrun : Bool,
      print_prompt : String?,
      output_format : String?,
    )
      ensure_config_dirs

      path = PERSONAS_DIR / "#{name}.toml"

      unless File.exists?(path)
        STDERR.puts "Error: Unknown persona '#{name}'"
        STDERR.puts ""
        display_available_personas
        STDERR.puts ""
        STDERR.puts "Commands:"
        STDERR.puts "  claude-persona list       List available personas"
        STDERR.puts "  claude-persona generate   Create a new persona"
        exit(1)
      end

      begin
        # Pre-parse migration must run BEFORE loading to fix TOML syntax issues
        # that would corrupt data during parsing (e.g., """ -> ''' conversion)
        if Migrator.pre_parse_migrate(path)
          puts "Migrated persona '#{name}' string delimiters (\"\"\" -> ''')"
        end

        config = PersonaConfig.load(name)

        # Check for and perform upgrade if needed (post-parse migrations)
        config = maybe_upgrade_persona(name, config, path)

        # Validate flag combinations
        if print_prompt && resume_id
          STDERR.puts "Error: -p/--print and --resume cannot be used together"
          exit(1)
        end

        if output_format && !print_prompt
          STDERR.puts "Error: --output-format requires -p/--print"
          exit(1)
        end

        if dryrun
          builder = CommandBuilder.new(
            config,
            resume_session_id: resume_id,
            vibe: vibe,
            print_prompt: print_prompt,
            output_format: output_format,
          )
          puts builder.format_command
          return
        end

        if print_prompt
          # Validate output_format if provided
          if fmt = output_format
            unless ["text", "json", "stream-json"].includes?(fmt)
              STDERR.puts "Error: Invalid output format '#{fmt}'. Must be: text, json, stream-json"
              exit(1)
            end
          end

          builder = CommandBuilder.new(
            config,
            vibe: vibe,
            print_prompt: print_prompt,
            output_format: output_format,
          )
          args = builder.build

          status = Process.run("claude",
            args: args,
            input: Process::Redirect::Inherit,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit,
          )
          exit(status.exit_code)
        end

        session = Session.new(name, config, resume_id, vibe)
        exit_code = session.run
        exit(exit_code)
      rescue e : ConfigError
        STDERR.puts "Error: #{e.message}"
        exit(1)
      end
    end

    # Check if persona needs upgrade and perform it
    private def self.maybe_upgrade_persona(name : String, config : PersonaConfig, path : Path) : PersonaConfig
      return config unless Migrator.needs_upgrade?(config)

      old_version = Migrator.effective_version(config)
      result = Migrator.upgrade(name, config, path)

      case result
      when Migrator::Result::Upgraded
        puts "Upgraded persona '#{name}' (#{old_version} -> #{VERSION})"
        # Reload config after upgrade
        PersonaConfig.load(name)
      when Migrator::Result::ReadOnly
        STDERR.puts "Warning: Persona '#{name}' is outdated (#{old_version}) but file is read-only"
        config
      when Migrator::Result::Failed
        STDERR.puts "Warning: Failed to upgrade persona '#{name}' (#{old_version} -> #{VERSION})"
        config
      else
        config
      end
    end

    private def self.list_personas
      ensure_config_dirs

      personas = get_persona_names

      if personas.empty?
        puts "No personas found. Create one with: claude-persona generate"
        return
      end

      puts "Available personas:"
      puts ""

      personas.each do |name|
        path = PERSONAS_DIR / "#{name}.toml"
        begin
          config = PersonaConfig.load(name)

          # Show version status indicator
          version_display = if version = config.version
                              if Migrator.needs_upgrade?(config)
                                "v#{version} -> v#{VERSION}" # Outdated indicator
                              else
                                "v#{version}"
                              end
                            else
                              "unversioned -> v#{VERSION}" # No version yet
                            end

          puts "  #{name} (#{version_display})"
          unless config.description.empty?
            puts "    #{config.description}"
          end
          puts "    Model: #{config.model}"
          if mcp = config.mcp
            unless mcp.configs.empty?
              puts "    MCPs: #{mcp.configs.join(", ")}"
            end
          end
          if perms = config.permissions
            puts "    Permission mode: #{perms.mode}"
          end
          puts "    Path: #{path}"
        rescue e
          puts "  #{name}"
          puts "    (error: #{e.message})"
          puts "    Path: #{path}"
        end
        puts ""
      end
    end

    private def self.generate_persona(dryrun : Bool = false)
      ensure_config_dirs

      system_prompt = ClaudePersona.build_generator_system_prompt
      initial_message = ClaudePersona.build_generator_initial_message

      allowed_tools = ["Read", "Write", "Glob", "AskUserQuestion"]

      args = [
        "--model", GENERATOR_MODEL,
        "--system-prompt", system_prompt,
        "--add-dir", PERSONAS_DIR.to_s,
        "--add-dir", MCP_DIR.to_s,
        "--allowed-tools", allowed_tools.join(","),
        "--", # Separates flags from positional argument
        initial_message,
      ]

      if dryrun
        puts format_generate_command(args, initial_message)
        return
      end

      puts "✨ Claude Persona Generator"
      puts "   Model: #{GENERATOR_MODEL}"
      puts "   Directories:"
      puts "     - #{PERSONAS_DIR}"
      puts "     - #{MCP_DIR}"
      puts "   Allowed tools: #{allowed_tools.join(", ")}"
      puts ""
      puts "   Claude will interview you and create a new persona config."
      puts ""

      Process.run("claude",
        args: args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
    end

    private def self.format_generate_command(args : Array(String), initial_message : String? = nil) : String
      lines = ["# claude-persona v#{VERSION}", "claude \\"]

      # Group args into flag + value(s) for readable output
      i = 0
      while i < args.size
        arg = args[i]

        # Skip the -- separator and initial_message (handled separately)
        if arg == "--"
          break
        end

        if arg.starts_with?("--")
          # Collect all values until next flag
          values = [] of String
          j = i + 1
          while j < args.size && !args[j].starts_with?("--")
            values << args[j]
            j += 1
          end

          if values.empty?
            lines << "  #{arg} \\"
          elsif values.size == 1
            value = values.first
            display_value = if value.size > 60
                              "\"#{value[0, 57]}...\""
                            else
                              value.includes?(" ") ? "\"#{value}\"" : value
                            end
            lines << "  #{arg} #{display_value} \\"
          else
            # Multiple values (e.g., --allowed-tools Read Write Glob)
            lines << "  #{arg} #{values.join(" ")} \\"
          end

          i = j
        else
          i += 1
        end
      end

      # Add initial message with -- separator if present
      if msg = initial_message
        display_msg = if msg.size > 60
                        "\"#{msg[0, 57]}...\""
                      else
                        "\"#{msg}\""
                      end
        lines << "  -- #{display_msg}"
      else
        lines[-1] = lines[-1].rchop(" \\")
      end

      lines.join("\n")
    end

    private def self.show_persona(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona show <persona>"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      path = PERSONAS_DIR / "#{name}.toml"
      unless File.exists?(path)
        STDERR.puts "Error: Persona '#{name}' not found"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      puts File.read(path)
    end

    private def self.rename_persona(old_name : String?, new_name : String?)
      unless old_name && new_name
        STDERR.puts "Usage: claude-persona rename <old-name> <new-name>"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      # Validate old persona exists
      old_path = PERSONAS_DIR / "#{old_name}.toml"
      unless File.exists?(old_path)
        STDERR.puts "Error: Persona '#{old_name}' not found"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      # Validate new name doesn't exist
      new_path = PERSONAS_DIR / "#{new_name}.toml"
      if File.exists?(new_path)
        STDERR.puts "Error: Persona '#{new_name}' already exists"
        exit(1)
      end

      # Validate new name is filesystem-safe
      unless new_name.matches?(/^[a-zA-Z0-9_-]+$/)
        STDERR.puts "Error: Persona name can only contain letters, numbers, hyphens, and underscores"
        exit(1)
      end

      # Validate not a reserved name
      if RESERVED_NAMES.includes?(new_name.downcase)
        STDERR.puts "Error: '#{new_name}' is a reserved name (conflicts with subcommand)"
        exit(1)
      end

      # Perform rename
      File.rename(old_path, new_path)

      puts "Renamed '#{old_name}' to '#{new_name}'"
      puts "  #{new_path}"
    end

    private def self.remove_persona(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona remove <persona>"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      path = PERSONAS_DIR / "#{name}.toml"
      unless File.exists?(path)
        STDERR.puts "Error: Persona '#{name}' not found"
        STDERR.puts ""
        display_available_personas
        exit(1)
      end

      return unless confirm?("Remove persona '#{name}'?")

      File.delete(path)
      puts "Removed #{path}"
    end

    private def self.handle_mcp_command(args : Array(String))
      if args.empty?
        show_mcp_help
        return
      end

      subcommand = args[0]
      rest = args[1..]? || [] of String

      case subcommand
      when "available"
        McpHandler.display_available
      when "list"
        list_mcps
      when "import"
        import_mcp(rest.first?)
      when "import-all"
        import_all_mcps
      when "show"
        show_mcp(rest.first?)
      when "remove"
        remove_mcp(rest.first?)
      else
        show_mcp_help
      end
    end

    private def self.list_mcps
      mcps = McpHandler.list

      if mcps.empty?
        puts "No MCP configs found."
        puts "See available: claude-persona mcp available"
        puts "Import with:   claude-persona mcp import <name>"
        return
      end

      puts "MCP configs:"
      mcps.each do |name|
        type = get_mcp_type(name)
        path = MCP_DIR / "#{name}.json"
        puts "  #{name} (#{type}): #{path}"
      end
    end

    private def self.get_mcp_type(name : String) : String
      path = MCP_DIR / "#{name}.json"
      return "unknown" unless File.exists?(path)

      begin
        data = JSON.parse(File.read(path))
        if servers = data["mcpServers"]?
          if server = servers[name]?
            return server["type"]?.try(&.as_s) || "unknown"
          end
        end
      rescue
      end
      "unknown"
    end

    private def self.display_imported_mcps
      mcps = McpHandler.list
      if mcps.empty?
        STDERR.puts "No imported MCP configs."
      else
        STDERR.puts "Imported MCP configs:"
        mcps.each do |name|
          type = get_mcp_type(name)
          STDERR.puts "  #{name} (#{type})"
        end
      end
    end

    private def self.import_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp import <name>"
        STDERR.puts ""
        McpHandler.display_available
        exit(1)
      end

      ensure_config_dirs

      unless McpHandler.import(name)
        exit(1)
      end
    end

    private def self.import_all_mcps
      ensure_config_dirs

      count = McpHandler.import_all

      if count > 0
        puts ""
        puts "Imported #{count} MCP config(s)."
      end
    end

    private def self.show_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp show <name>"
        STDERR.puts ""
        display_imported_mcps
        exit(1)
      end

      path = MCP_DIR / "#{name}.json"
      unless File.exists?(path)
        STDERR.puts "Error: MCP config '#{name}' not found"
        STDERR.puts ""
        display_imported_mcps
        exit(1)
      end

      puts File.read(path)
    end

    private def self.remove_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp remove <name>"
        STDERR.puts ""
        display_imported_mcps
        exit(1)
      end

      path = MCP_DIR / "#{name}.json"
      unless File.exists?(path)
        STDERR.puts "Error: MCP config '#{name}' not found"
        STDERR.puts ""
        display_imported_mcps
        exit(1)
      end

      return unless confirm?("Remove MCP config '#{name}'?")

      File.delete(path)
      puts "Removed #{path}"
    end

    private def self.get_persona_names : Array(String)
      return [] of String unless Dir.exists?(PERSONAS_DIR)

      Dir.children(PERSONAS_DIR)
        .select { |f| f.ends_with?(".toml") }
        .map { |f| f.chomp(".toml") }
        .sort
    end

    private def self.display_available_personas
      personas = get_persona_names
      if personas.empty?
        STDERR.puts "No personas found."
      else
        STDERR.puts "Available personas:"
        personas.each { |p| STDERR.puts "  #{p}" }
      end
    end

    private def self.ensure_config_dirs
      Dir.mkdir_p(PERSONAS_DIR)
      Dir.mkdir_p(MCP_DIR)
    end

    private def self.confirm?(message : String) : Bool
      print "#{message} [Yn] "
      response = gets
      return true if response.nil? || response.empty? || response.downcase.starts_with?("y")
      false
    end

    private def self.show_mcp_help
      puts <<-HELP
      claude-persona mcp - Manage MCP configurations

      Usage:
        claude-persona mcp available          List MCPs available to import
        claude-persona mcp list               List imported MCP configs
        claude-persona mcp import <name>      Import MCP config from Claude
        claude-persona mcp import-all         Import all MCPs from Claude
        claude-persona mcp show <name>        Display imported MCP config
        claude-persona mcp remove <name>      Delete imported MCP config
      HELP
    end

    private def self.handle_update_command(args : Array(String))
      # Check for help subcommand first
      if args.includes?("help")
        show_update_help
        return
      end

      # Validate prerequisites
      unless command_exists?("curl")
        STDERR.puts "Error: curl is required for updates"
        STDERR.puts "Install curl and try again"
        exit(1)
      end

      unless command_exists?("bash")
        STDERR.puts "Error: bash is required for updates"
        exit(1)
      end

      # Build script URL
      script_url = "https://raw.githubusercontent.com/kellyredding/claude-persona/main/scripts/update.sh"

      # Pass subcommands to script
      script_args = args.join(" ")

      # Fetch and execute
      status = Process.run(
        "bash",
        args: ["-c", "curl -fsSL '#{script_url}' | bash -s -- #{script_args}"],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      exit(status.exit_code)
    end

    private def self.command_exists?(cmd : String) : Bool
      Process.run("which", args: [cmd], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
    end

    private def self.show_update_help
      puts <<-HELP
      claude-persona update - Update to the latest version

      Usage:
        claude-persona update           Update to latest version
        claude-persona update preview   Preview update without making changes
        claude-persona update force     Reinstall latest (even if up-to-date)
        claude-persona update help      Show this help

      The update downloads the latest release from GitHub, verifies the
      checksum, and replaces the current binary.

      Update script: https://raw.githubusercontent.com/kellyredding/claude-persona/main/scripts/update.sh
      HELP
    end
  end
end
