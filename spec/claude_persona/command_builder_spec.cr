require "../spec_helper"

describe ClaudePersona::CommandBuilder do
  describe "#build" do
    it "includes model flag" do
      config = minimal_config(model: "opus")
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--model")
      args.should contain("opus")
    end

    it "includes system prompt when present" do
      config = config_with_prompt("You are helpful.")
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--system-prompt")
      args.should contain("You are helpful.")
    end

    it "omits system prompt when empty" do
      config = minimal_config
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should_not contain("--system-prompt")
    end

    it "expands home directory in paths" do
      config = config_with_directories(["~/projects"])
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--add-dir")
      args.any? { |a| a.starts_with?("/") && a.ends_with?("/projects") }.should be_true
      args.should_not contain("~/projects")
    end

    it "adds multiple directories" do
      config = config_with_directories(["~/one", "~/two"])
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.count("--add-dir").should eq(2)
    end

    it "includes allowed tools" do
      config = config_with_tools(allowed: ["Read", "Write"])
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--allowed-tools")
      args.should contain("Read")
      args.should contain("Write")
    end

    it "includes disallowed tools" do
      config = config_with_tools(disallowed: ["Bash(rm:*)"])
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--disallowed-tools")
      args.should contain("Bash(rm:*)")
    end

    it "includes permission mode" do
      config = config_with_permissions("acceptEdits")
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--permission-mode")
      args.should contain("acceptEdits")
    end

    it "adds --dangerously-skip-permissions when vibe is true" do
      config = minimal_config
      builder = ClaudePersona::CommandBuilder.new(config, vibe: true)

      args = builder.build
      args.should contain("--dangerously-skip-permissions")
    end

    it "omits --dangerously-skip-permissions when vibe is false" do
      config = minimal_config
      builder = ClaudePersona::CommandBuilder.new(config, vibe: false)

      args = builder.build
      args.should_not contain("--dangerously-skip-permissions")
    end

    it "adds --resume with session id" do
      config = minimal_config
      builder = ClaudePersona::CommandBuilder.new(config, resume_session_id: "abc-123")

      args = builder.build
      args.should contain("--resume")
      args.should contain("abc-123")
    end

    it "adds --strict-mcp-config when MCPs are configured" do
      # This test requires MCP fixture files to exist
      config = config_with_mcp(["test-mcp"])
      builder = ClaudePersona::CommandBuilder.new(config)

      args = builder.build
      args.should contain("--strict-mcp-config")
      args.should contain("--mcp-config")
    end
  end

  describe "#format_command" do
    it "includes version header" do
      config = minimal_config(model: "sonnet")
      builder = ClaudePersona::CommandBuilder.new(config)

      output = builder.format_command
      output.should start_with("# claude-persona v")
    end

    it "formats command with backslash continuations" do
      config = minimal_config(model: "sonnet")
      builder = ClaudePersona::CommandBuilder.new(config)

      output = builder.format_command
      output.should contain("claude \\")
      output.should contain("--model sonnet")
    end

    it "truncates long values" do
      long_prompt = "x" * 100
      config = config_with_prompt(long_prompt)
      builder = ClaudePersona::CommandBuilder.new(config)

      output = builder.format_command
      output.should contain("...")
      output.should_not contain("x" * 100)
    end

    it "quotes values with spaces" do
      config = config_with_prompt("two words")
      builder = ClaudePersona::CommandBuilder.new(config)

      output = builder.format_command
      output.should contain("\"two words\"")
    end
  end
end

# Test helpers
def minimal_config(model : String = "sonnet") : ClaudePersona::PersonaConfig
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"
  model = "#{model}"
  TOML
  )
end

def config_with_prompt(prompt : String) : ClaudePersona::PersonaConfig
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"

  [prompt]
  system = "#{prompt}"
  TOML
  )
end

def config_with_directories(dirs : Array(String)) : ClaudePersona::PersonaConfig
  dirs_toml = dirs.map { |d| "\"#{d}\"" }.join(", ")
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"

  [directories]
  allowed = [#{dirs_toml}]
  TOML
  )
end

def config_with_tools(allowed : Array(String) = [] of String, disallowed : Array(String) = [] of String) : ClaudePersona::PersonaConfig
  allowed_toml = allowed.map { |t| "\"#{t}\"" }.join(", ")
  disallowed_toml = disallowed.map { |t| "\"#{t}\"" }.join(", ")
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"

  [tools]
  allowed = [#{allowed_toml}]
  disallowed = [#{disallowed_toml}]
  TOML
  )
end

def config_with_permissions(mode : String) : ClaudePersona::PersonaConfig
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"

  [permissions]
  mode = "#{mode}"
  TOML
  )
end

def config_with_mcp(configs : Array(String)) : ClaudePersona::PersonaConfig
  configs_toml = configs.map { |c| "\"#{c}\"" }.join(", ")
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"

  [mcp]
  configs = [#{configs_toml}]
  TOML
  )
end
