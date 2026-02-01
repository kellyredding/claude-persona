module ClaudePersona
  module Migrator
    # Result of a migration attempt
    enum Result
      AlreadyCurrent # No upgrade needed
      Upgraded       # Successfully upgraded
      Failed         # Migration failed (backup preserved)
      ReadOnly       # File is read-only
    end

    # Pre-parse migration: runs BEFORE TOML parsing to fix issues that would
    # corrupt data during parsing. This is necessary because toml.cr has a bug
    # with embedded quotes in multi-line basic strings (""").
    #
    # Returns true if migration was performed, false if not needed
    def self.pre_parse_migrate(path : Path) : Bool
      return false unless File.exists?(path)

      content = File.read(path)

      # Extract version from raw content using regex
      version = extract_version_from_content(content) || "0.0.0"

      # Check if pre-parse migration is needed (versions before 1.1.0)
      return false unless compare_versions(version, "1.1.0") < 0

      # Check if file is writable
      return false unless File::Info.writable?(path)

      # Check if there are any """ to convert
      return false unless content.includes?("\"\"\"")

      # Create backup
      backup_path = Path.new("#{path}.bak")
      File.copy(path, backup_path)

      begin
        # Convert basic strings (""") to literal strings (''')
        migrated = content.gsub("\"\"\"", "'''")

        # Update version line if present, or add it after model line
        # Stamp with "1.1.0" (not VERSION) so post-parse migrations can run for later versions
        if migrated =~ /^version\s*=\s*["'][^"']*["']/m
          migrated = migrated.gsub(/^version\s*=\s*["'][^"']*["']/m, "version = \"1.1.0\"")
        elsif migrated =~ /^model\s*=\s*["'][^"']*["']/m
          # Insert version after model line
          migrated = migrated.gsub(/^(model\s*=\s*["'][^"']*["'])/m, "\\1\nversion = \"1.1.0\"")
        else
          # Fallback: add at beginning (shouldn't happen with valid configs)
          migrated = "version = \"1.1.0\"\n" + migrated
        end

        File.write(path, migrated)

        # Remove backup on success
        File.delete(backup_path) if File.exists?(backup_path)

        true
      rescue ex
        # Restore from backup on failure
        if File.exists?(backup_path)
          File.copy(backup_path, path)
          File.delete(backup_path)
        end
        false
      end
    end

    # Extract version string from raw file content without parsing TOML
    private def self.extract_version_from_content(content : String) : String?
      if content =~ /^version\s*=\s*["']([^"']+)["']/m
        $1
      else
        nil
      end
    end

    # Check if persona needs upgrade
    def self.needs_upgrade?(config : PersonaConfig) : Bool
      effective_version(config) != VERSION
    end

    # Get effective version (nil treated as "0.0.0")
    def self.effective_version(config : PersonaConfig) : String
      config.version || "0.0.0"
    end

    # Upgrade persona at path, returns result
    def self.upgrade(name : String, config : PersonaConfig, path : Path) : Result
      return Result::AlreadyCurrent unless needs_upgrade?(config)

      # Check if file is writable
      unless File::Info.writable?(path)
        return Result::ReadOnly
      end

      # Create backup
      backup_path = Path.new("#{path}.bak")
      File.copy(path, backup_path)

      begin
        # Run migrations
        run_migrations(config, path)

        # Remove backup on success
        File.delete(backup_path) if File.exists?(backup_path)

        Result::Upgraded
      rescue ex
        # Restore from backup on failure
        if File.exists?(backup_path)
          File.copy(backup_path, path)
          File.delete(backup_path)
        end
        Result::Failed
      end
    end

    # Run all applicable migrations in sequence
    private def self.run_migrations(config : PersonaConfig, path : Path)
      from_version = effective_version(config)

      # Migration to 1.1.0 is handled by pre_parse_migrate (string delimiters)
      # Future post-parse migrations would go here:
      #
      # if compare_versions(from_version, "1.2.0") < 0
      #   config = migrate_to_1_2_0(config)
      # end

      # Stamp with current version
      TomlWriter.write(path, config, VERSION)
    end

    # Compare semantic versions: -1 if a < b, 0 if equal, 1 if a > b
    # Used for future migration ordering
    def self.compare_versions(a : String, b : String) : Int32
      a_parts = a.split(".").map(&.to_i)
      b_parts = b.split(".").map(&.to_i)

      # Pad to same length
      max_len = [a_parts.size, b_parts.size].max
      while a_parts.size < max_len
        a_parts << 0
      end
      while b_parts.size < max_len
        b_parts << 0
      end

      a_parts.zip(b_parts).each do |av, bv|
        return -1 if av < bv
        return 1 if av > bv
      end

      0
    end
  end
end
