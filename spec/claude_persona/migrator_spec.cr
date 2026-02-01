require "../spec_helper"

describe ClaudePersona::Migrator do
  describe ".needs_upgrade?" do
    it "returns true when version is nil" do
      toml = <<-TOML
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      ClaudePersona::Migrator.needs_upgrade?(config).should be_true
    end

    it "returns true when version is older than current" do
      toml = <<-TOML
      version = "0.0.1"
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      ClaudePersona::Migrator.needs_upgrade?(config).should be_true
    end

    it "returns false when version matches current" do
      toml = <<-TOML
      version = "#{ClaudePersona::VERSION}"
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      ClaudePersona::Migrator.needs_upgrade?(config).should be_false
    end
  end

  describe ".effective_version" do
    it "returns version when present" do
      toml = <<-TOML
      version = "1.2.3"
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      ClaudePersona::Migrator.effective_version(config).should eq("1.2.3")
    end

    it "returns 0.0.0 when version is nil" do
      toml = <<-TOML
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      ClaudePersona::Migrator.effective_version(config).should eq("0.0.0")
    end
  end

  describe ".compare_versions" do
    it "compares equal versions" do
      ClaudePersona::Migrator.compare_versions("1.0.0", "1.0.0").should eq(0)
    end

    it "compares major versions" do
      ClaudePersona::Migrator.compare_versions("1.0.0", "2.0.0").should eq(-1)
      ClaudePersona::Migrator.compare_versions("2.0.0", "1.0.0").should eq(1)
    end

    it "compares minor versions" do
      ClaudePersona::Migrator.compare_versions("1.1.0", "1.2.0").should eq(-1)
      ClaudePersona::Migrator.compare_versions("1.2.0", "1.1.0").should eq(1)
    end

    it "compares patch versions" do
      ClaudePersona::Migrator.compare_versions("1.0.1", "1.0.2").should eq(-1)
      ClaudePersona::Migrator.compare_versions("1.0.2", "1.0.1").should eq(1)
    end

    it "handles different length versions" do
      ClaudePersona::Migrator.compare_versions("1.0", "1.0.0").should eq(0)
      ClaudePersona::Migrator.compare_versions("1.0", "1.0.1").should eq(-1)
    end
  end

  describe "Migrator::Result" do
    it "has all expected enum values" do
      ClaudePersona::Migrator::Result::AlreadyCurrent.should_not be_nil
      ClaudePersona::Migrator::Result::Upgraded.should_not be_nil
      ClaudePersona::Migrator::Result::Failed.should_not be_nil
      ClaudePersona::Migrator::Result::ReadOnly.should_not be_nil
    end
  end

  describe ".pre_parse_migrate" do
    it "converts basic strings to literal strings for versions < 1.1.0" do
      path = Path.new(File.tempname("pre-parse-test", ".toml"))

      begin
        # Write a config with old version and basic strings
        content = <<-TOML
        version = "1.0.0"
        model = "sonnet"

        [prompt]
        system = """
        Test with "embedded quotes" here.
        """
        TOML
        File.write(path, content)

        # Run pre-parse migration
        result = ClaudePersona::Migrator.pre_parse_migrate(path)
        result.should be_true

        # Verify the file was converted
        migrated = File.read(path)
        migrated.should contain("'''")
        migrated.should_not contain("\"\"\"")
        # Should stamp with 1.1.0 (not VERSION) so post-parse migrations can run
        migrated.should contain("version = \"1.1.0\"")

        # Verify content can now be parsed without corruption
        config = ClaudePersona::PersonaConfig.from_toml(migrated)
        prompt = config.prompt
        prompt.should_not be_nil
        prompt.not_nil!.system.should contain("\"embedded quotes\"")
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "returns false when already at current version" do
      path = Path.new(File.tempname("pre-parse-test", ".toml"))

      begin
        content = <<-TOML
        version = "#{ClaudePersona::VERSION}"
        model = "sonnet"
        TOML
        File.write(path, content)

        result = ClaudePersona::Migrator.pre_parse_migrate(path)
        result.should be_false
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "returns false when no basic strings to convert" do
      path = Path.new(File.tempname("pre-parse-test", ".toml"))

      begin
        # Config with old version but no """ strings
        content = <<-TOML
        version = "1.0.0"
        model = "sonnet"

        [prompt]
        system = "Simple single-line prompt"
        TOML
        File.write(path, content)

        result = ClaudePersona::Migrator.pre_parse_migrate(path)
        result.should be_false
      ensure
        File.delete(path) if File.exists?(path)
      end
    end

    it "returns false for non-existent file" do
      path = Path.new("/nonexistent/path/test.toml")
      result = ClaudePersona::Migrator.pre_parse_migrate(path)
      result.should be_false
    end
  end
end
