require "../spec_helper"

describe ClaudePersona::PersonaConfig do
  describe ".from_toml" do
    it "parses minimal config with defaults" do
      toml = <<-TOML
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.version.should be_nil
      config.description.should eq("") # default
      config.model.should eq("sonnet")
      config.effort.should be_nil
      config.directories.should be_nil
      config.mcp.should be_nil
      config.tools.should be_nil
      config.permissions.should be_nil
      config.prompt.should be_nil
    end

    it "parses version field" do
      toml = <<-TOML
      version = "0.1.1"
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.version.should eq("0.1.1")
    end

    it "defaults version to nil when missing" do
      toml = <<-TOML
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.version.should be_nil
    end

    it "parses effort field" do
      toml = <<-TOML
      model = "opus"
      effort = "high"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.effort.should eq("high")
    end

    it "treats an empty effort as unset" do
      toml = <<-TOML
      model = "opus"
      effort = ""
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.effort.should be_nil
    end

    it "parses all config sections" do
      toml = <<-TOML
      description = "Full config"
      model = "opus"

      [directories]
      allowed = ["~/projects", "~/docs"]

      [mcp]
      configs = ["context7", "linear"]

      [tools]
      allowed = ["Read", "Write"]
      disallowed = ["Bash(rm:*)"]

      [permissions]
      mode = "acceptEdits"

      [prompt]
      system = "You are helpful."
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.description.should eq("Full config")
      config.model.should eq("opus")
      config.directories.not_nil!.allowed.should eq(["~/projects", "~/docs"])
      config.mcp.not_nil!.configs.should eq(["context7", "linear"])
      config.tools.not_nil!.allowed.should eq(["Read", "Write"])
      config.tools.not_nil!.disallowed.should eq(["Bash(rm:*)"])
      config.permissions.not_nil!.mode.should eq("acceptEdits")
      config.prompt.not_nil!.system.should eq("You are helpful.")
    end

    it "handles multiline system prompts" do
      toml = <<-TOML
      description = "Multiline test"

      [prompt]
      system = """
      Line one.
      Line two.
      Line three.
      """
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.prompt.not_nil!.system.should contain("Line one.")
      config.prompt.not_nil!.system.should contain("Line two.")
    end

    it "parses initial_message in prompt section" do
      toml = <<-TOML
      description = "Test"

      [prompt]
      system = "You are helpful."
      initial_message = "Start working on the task."
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.prompt.not_nil!.system.should eq("You are helpful.")
      config.prompt.not_nil!.initial_message.should eq("Start working on the task.")
    end

    it "defaults initial_message to empty string" do
      toml = <<-TOML
      description = "Test"

      [prompt]
      system = "You are helpful."
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.prompt.not_nil!.initial_message.should eq("")
    end
  end
end
