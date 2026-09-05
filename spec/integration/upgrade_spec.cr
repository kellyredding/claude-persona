require "../spec_helper"
require "file_utils"

describe "upgrade integration" do
  describe "persona launch with upgrade" do
    it "shows upgrade message for unversioned persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-upgrade.toml"

        File.write(persona_path, <<-TOML)
        description = "Test upgrade"
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["test-upgrade", "--dry-run"])[:output]

        output.should contain("Upgraded persona 'test-upgrade'")
        output.should contain("0.0.0 ->")

        # Verify file was updated
        updated_content = File.read(persona_path)
        updated_content.should contain("version = \"#{ClaudePersona::VERSION}\"")
      end
    end

    it "shows upgrade message for outdated persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-upgrade.toml"

        File.write(persona_path, <<-TOML)
        version = "0.0.1"
        description = "Test upgrade"
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["test-upgrade", "--dry-run"])[:output]

        output.should contain("Upgraded persona 'test-upgrade'")
        output.should contain("0.0.1 ->")
      end
    end

    it "does not show upgrade message for current version" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-current.toml"

        File.write(persona_path, <<-TOML)
        version = "#{ClaudePersona::VERSION}"
        description = "Current version"
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["test-current", "--dry-run"])[:output]

        output.should_not contain("Upgraded persona")
      end
    end

    it "warns and leaves a persona written by a newer claude-persona alone" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-newer.toml"

        original = <<-TOML
        version = "99.0.0"
        description = "From the future"
        model = "sonnet"
        TOML
        File.write(persona_path, original)

        result = run_with_temp_config(temp_dir, ["test-newer", "--dry-run"])

        result[:error].should contain("newer claude-persona")
        result[:output].should_not contain("Upgraded persona")

        # The whole point: an older binary must not rewrite it back down.
        File.read(persona_path).should eq(original)
      end
    end

    it "warns but continues for read-only persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-readonly.toml"

        File.write(persona_path, <<-TOML)
        description = "Read-only test"
        model = "sonnet"
        TOML

        # Make file read-only
        File.chmod(persona_path, 0o444)

        begin
          result = run_with_temp_config(temp_dir, ["test-readonly", "--dry-run"])

          # Should warn but still output dry-run command
          result[:error].should contain("read-only")
          result[:output].should contain("claude")
        ensure
          # Restore permissions for cleanup
          File.chmod(persona_path, 0o644)
        end
      end
    end

    it "preserves all config data after upgrade" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-full-upgrade.toml"

        File.write(persona_path, <<-TOML)
        description = "Full test"
        model = "opus"

        [directories]
        allowed = ["~/projects"]

        [mcp]
        configs = ["context7"]

        [tools]
        allowed = ["Read", "Write"]
        disallowed = ["Bash(rm:*)"]

        [permissions]
        mode = "acceptEdits"

        [prompt]
        system = "Be helpful."
        initial_message = "Hello"
        TOML

        run_with_temp_config(temp_dir, ["test-full-upgrade", "--dry-run"])

        # Reload and verify all fields preserved
        updated_content = File.read(persona_path)
        updated_content.should contain("version = \"#{ClaudePersona::VERSION}\"")
        updated_content.should contain("description = \"Full test\"")
        updated_content.should contain("model = \"opus\"")
        updated_content.should contain("[directories]")
        updated_content.should contain("~/projects")
        updated_content.should contain("[mcp]")
        updated_content.should contain("context7")
        updated_content.should contain("[tools]")
        updated_content.should contain("Read")
        updated_content.should contain("Bash(rm:*)")
        updated_content.should contain("[permissions]")
        updated_content.should contain("acceptEdits")
        updated_content.should contain("[prompt]")
        updated_content.should contain("Be helpful.")
        updated_content.should contain("Hello")
      end
    end
  end

  describe "list command with versions" do
    it "shows version for versioned persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-list.toml"

        File.write(persona_path, <<-TOML)
        version = "0.1.1"
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["list"])[:output]

        output.should contain("test-list")
        output.should contain("v0.1.1")
      end
    end

    it "shows upgrade indicator for outdated persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-old.toml"

        File.write(persona_path, <<-TOML)
        version = "0.0.1"
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["list"])[:output]

        output.should contain("test-old")
        output.should contain("v0.0.1 -> v#{ClaudePersona::VERSION}")
      end
    end

    it "shows unversioned indicator for pre-versioning persona" do
      with_temp_config_dir do |temp_dir|
        persona_path = temp_dir / "personas" / "test-nover.toml"

        File.write(persona_path, <<-TOML)
        model = "sonnet"
        TOML

        output = run_with_temp_config(temp_dir, ["list"])[:output]

        output.should contain("test-nover")
        output.should contain("unversioned -> v#{ClaudePersona::VERSION}")
      end
    end
  end
end
