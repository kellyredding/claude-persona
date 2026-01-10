require "../spec_helper"

describe ClaudePersona::PersonaConfig do
  describe ".from_toml" do
    it "parses minimal config with defaults" do
      toml = <<-TOML
      model = "sonnet"
      TOML

      config = ClaudePersona::PersonaConfig.from_toml(toml)
      config.description.should eq("") # default
      config.model.should eq("sonnet")
      config.directories.should be_nil
      config.mcp.should be_nil
      config.tools.should be_nil
      config.permissions.should be_nil
      config.prompt.should be_nil
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
  end
end
