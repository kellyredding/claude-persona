require "option_parser"

module ClaudePersona
  class CLI
    # Subcommand names that cannot be used as persona names
    RESERVED_NAMES = %w[list generate show rename mcp help version]

    def self.run(args : Array(String))
      # Flag state
      vibe = false
      dryrun = false
      resume_id : String? = nil
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
        puts "claude-persona #{VERSION}"
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
      when "mcp"
        handle_mcp_command(rest)
      when "help"
        puts parser
      when "version"
        puts "claude-persona #{VERSION}"
      else
        # Assume it's a persona name, validate and launch
        validate_and_launch_persona(command, resume_id, vibe, dryrun)
      end
    end

    private def self.build_banner : String
      <<-BANNER
      Usage: claude-persona [persona|command] [options]

      Launch a persona:
        claude-persona <persona>              Launch Claude with persona
        claude-persona <persona> --resume ID  Resume a session

      Commands:
        list                    List available personas
        generate                Create new persona interactively
        show <persona>          Display persona configuration
        rename <old> <new>      Rename a persona
        mcp list                List exported MCP configs
        mcp export <name>       Export MCP config from Claude
        mcp export-all          Export all MCPs from Claude
        mcp show <name>         Display MCP config JSON
        mcp remove <name>       Delete MCP config file
      BANNER
    end

    private def self.validate_and_launch_persona(name : String, resume_id : String?, vibe : Bool, dryrun : Bool)
      ensure_config_dirs

      path = PERSONAS_DIR / "#{name}.toml"

      unless File.exists?(path)
        STDERR.puts "Error: Unknown persona '#{name}'"
        STDERR.puts ""
        STDERR.puts "Available commands:"
        STDERR.puts "  claude-persona list       List available personas"
        STDERR.puts "  claude-persona generate   Create a new persona"
        STDERR.puts "  claude-persona --help     Show all commands"
        exit(1)
      end

      begin
        config = PersonaConfig.load(name)

        if dryrun
          builder = CommandBuilder.new(config, resume_id, vibe)
          puts builder.format_command
          return
        end

        session = Session.new(name, config, resume_id, vibe)
        exit_code = session.run
        exit(exit_code)
      rescue e : ConfigError
        STDERR.puts "Error: #{e.message}"
        exit(1)
      end
    end

    private def self.list_personas
      ensure_config_dirs

      personas = Dir.children(PERSONAS_DIR)
        .select { |f| f.ends_with?(".toml") }
        .map { |f| f.chomp(".toml") }
        .sort

      if personas.empty?
        puts "No personas found. Create one with: claude-persona generate"
        return
      end

      puts "Available personas:"
      puts ""

      personas.each do |name|
        config = PersonaConfig.load(name)
        puts "  #{name}"
        unless config.description.empty?
          puts "    #{config.description}"
        end
        puts "    Model: #{config.model}"
        if mcp = config.mcp
          unless mcp.configs.empty?
            puts "    MCPs: #{mcp.configs.join(", ")}"
          end
        end
        puts ""
      end
    end

    private def self.generate_persona(dryrun : Bool = false)
      ensure_config_dirs

      generator_prompt = ClaudePersona.build_generator_prompt

      args = [
        "--system-prompt", generator_prompt,
        "--add-dir", PERSONAS_DIR.to_s,
        "--add-dir", MCP_DIR.to_s,
        "--allowed-tools", "Read", "Write", "Glob", "AskUserQuestion",
      ]

      if dryrun
        puts format_generate_command(args)
        return
      end

      puts "━━━ Claude Persona Generator ━━━"
      puts "Launching Claude to help you create a new persona..."
      puts "Claude will interview you and confirm the persona name before saving."
      puts ""

      Process.run("claude",
        args: args,
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )
    end

    private def self.format_generate_command(args : Array(String)) : String
      lines = ["# claude-persona v#{VERSION}", "claude \\"]

      # Group args into flag + value(s) for readable output
      i = 0
      while i < args.size
        arg = args[i]
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

      lines[-1] = lines[-1].rchop(" \\")
      lines.join("\n")
    end

    private def self.show_persona(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona show <persona>"
        exit(1)
      end

      path = PERSONAS_DIR / "#{name}.toml"
      unless File.exists?(path)
        STDERR.puts "Error: Persona '#{name}' not found"
        exit(1)
      end

      puts File.read(path)
    end

    private def self.rename_persona(old_name : String?, new_name : String?)
      unless old_name && new_name
        STDERR.puts "Usage: claude-persona rename <old-name> <new-name>"
        exit(1)
      end

      # Validate old persona exists
      old_path = PERSONAS_DIR / "#{old_name}.toml"
      unless File.exists?(old_path)
        STDERR.puts "Error: Persona '#{old_name}' not found"
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

    private def self.handle_mcp_command(args : Array(String))
      if args.empty?
        show_mcp_help
        return
      end

      subcommand = args[0]
      rest = args[1..]? || [] of String

      case subcommand
      when "list"
        list_mcps
      when "export"
        export_mcp(rest.first?)
      when "export-all"
        export_all_mcps
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
        puts "Export from Claude with: claude-persona mcp export <name>"
        return
      end

      puts "Available MCP configs:"
      mcps.each { |name| puts "  #{name}" }
    end

    private def self.export_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp export <name>"
        exit(1)
      end

      ensure_config_dirs

      puts "Checking Claude MCP config for '#{name}'..."

      unless McpHandler.export(name)
        exit(1)
      end
    end

    private def self.export_all_mcps
      ensure_config_dirs

      puts "Checking Claude MCP configs..."

      count = McpHandler.export_all

      if count > 0
        puts ""
        puts "Done. Exported #{count} MCP config(s)."
      else
        puts "No MCP configs found in Claude."
      end
    end

    private def self.show_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp show <name>"
        exit(1)
      end

      path = MCP_DIR / "#{name}.json"
      unless File.exists?(path)
        STDERR.puts "Error: MCP config '#{name}' not found"
        exit(1)
      end

      puts File.read(path)
    end

    private def self.remove_mcp(name : String?)
      unless name
        STDERR.puts "Usage: claude-persona mcp remove <name>"
        exit(1)
      end

      path = MCP_DIR / "#{name}.json"
      unless File.exists?(path)
        STDERR.puts "Error: MCP config '#{name}' not found"
        exit(1)
      end

      File.delete(path)
      puts "Removed #{path}"
    end

    private def self.ensure_config_dirs
      Dir.mkdir_p(PERSONAS_DIR)
      Dir.mkdir_p(MCP_DIR)
    end

    private def self.show_mcp_help
      puts <<-HELP
      claude-persona mcp - Manage MCP configurations

      Usage:
        claude-persona mcp list               List exported MCP configs
        claude-persona mcp export <name>      Export MCP config from Claude
        claude-persona mcp export-all         Export all MCPs from Claude
        claude-persona mcp show <name>        Display MCP config JSON
        claude-persona mcp remove <name>      Delete MCP config file
      HELP
    end
  end
end
