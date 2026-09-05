require "../spec_helper"

describe "dryrun integration" do
  describe "persona launch" do
    it "outputs claude command for basic persona" do
      output = run_dryrun("test-basic")

      output.should contain("claude")
      output.should contain("--model sonnet")
      output.should contain("--permission-mode default")
    end

    it "outputs claude command for full persona" do
      output = run_dryrun("test-full")

      output.should contain("--model opus")
      output.should contain("--permission-mode acceptEdits")
      output.should contain("--system-prompt")
      output.should contain("--add-dir")
      output.should contain("--allowed-tools")
      output.should contain("--disallowed-tools")
      output.should contain("--mcp-config")
      output.should contain("--strict-mcp-config")
    end

    it "includes --dangerously-skip-permissions with --vibe" do
      output = run_dryrun("test-basic", ["--vibe"])

      output.should contain("--dangerously-skip-permissions")
    end

    it "uses --resume when resuming" do
      output = run_dryrun("test-basic", ["--resume", "abc-123-def"])

      output.should contain("--resume")
      output.should contain("abc-123-def")
      output.should_not contain("--session-id")
    end

    it "combines --vibe and --resume" do
      output = run_dryrun("test-basic", ["--vibe", "--resume", "abc-123"])

      output.should contain("--dangerously-skip-permissions")
      output.should contain("--resume")
      output.should contain("abc-123")
      output.should_not contain("--session-id")
    end

    it "includes --session-id for new sessions" do
      output = run_dryrun("test-basic")

      output.should contain("--session-id")
    end

    it "includes initial_message for new session" do
      output = run_dryrun("test-with-initial-message")

      output.should contain("-- \"Start your task now.\"")
    end

    it "omits initial_message when resuming" do
      output = run_dryrun("test-with-initial-message", ["--resume", "session-123"])

      output.should contain("--resume")
      output.should contain("session-123")
      output.should_not contain("--session-id")
      output.should_not contain("Start your task now.")
      output.should_not contain("-- \"")
    end

    it "expands ~ in directory paths" do
      output = run_dryrun("test-full")

      output.should_not contain("~/")
      output.should match(/--add-dir \//)
    end

    it "outputs --print flag with prompt as positional arg" do
      output = run_dryrun("test-basic", ["-p", "Hello world"])

      output.should contain("--print")
      output.should contain("-- \"Hello world\"")
      output.should contain("--no-session-persistence")
    end

    it "outputs --output-format with --print" do
      output = run_dryrun("test-basic", ["-p", "Hello", "--output-format=json"])

      output.should contain("--print")
      output.should contain("--output-format")
      output.should contain("json")
    end

    it "uses print prompt instead of initial_message" do
      output = run_dryrun("test-with-initial-message", ["-p", "One-shot prompt"])

      output.should contain("--print")
      output.should contain("-- \"One-shot prompt\"")
      output.should_not contain("Start your task now.")
    end

    it "includes --settings placeholder for session tracking" do
      output = run_dryrun("test-basic")

      output.should contain("--settings")
      output.should contain("/tmp/claude-persona-settings-XXXXXX.json")
    end

    it "omits --settings in print mode" do
      output = run_dryrun("test-basic", ["-p", "Hello"])

      output.should_not contain("--settings")
    end

    it "uses provided --session-id instead of random UUID" do
      output = run_dryrun("test-basic", ["--session-id", "aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee"])

      output.should contain("--session-id")
      output.should contain("aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee")
    end

    it "combines --session-id with --vibe" do
      output = run_dryrun("test-basic", ["--session-id", "aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee", "--vibe"])

      output.should contain("--session-id")
      output.should contain("aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee")
      output.should contain("--dangerously-skip-permissions")
    end
  end

  describe "generate command" do
    it "outputs claude command for generate" do
      output = run_binary(["generate", "--dry-run"])[:output]

      output.should contain("claude")
      output.should contain("--model opus")
      output.should contain("--system-prompt")
      output.should contain("--add-dir")
      # Uses -- separator before initial message
      output.should contain("--")
      output.should contain("Greet the user")
    end
  end

  describe "error handling" do
    it "shows friendly error for missing MCP config" do
      result = run_binary(["test-missing-mcp", "--dry-run"])

      result[:error].should contain("MCP config 'nonexistent-mcp' not found")
    end

    it "lists personas gracefully when one has invalid TOML" do
      output = run_binary(["list"])[:output]

      output.should contain("test-invalid-toml")
      output.should contain("error:")
      # Should still list other valid personas
      output.should contain("test-basic")
    end

    it "errors when -p and --resume are used together" do
      result = run_binary(["test-basic", "-p", "Hello", "--resume", "abc-123"])

      result[:error].should contain("-p/--print and --resume cannot be used together")
    end

    it "errors when --output-format is used without -p" do
      result = run_binary(["test-basic", "--output-format=json"])

      result[:error].should contain("--output-format requires -p/--print")
    end

    it "errors when --session-id and --resume are used together" do
      result = run_binary(["test-basic", "--session-id", "some-uuid", "--resume", "abc-123"])

      result[:error].should contain("--session-id and --resume cannot be used together")
    end
  end

  describe "help output" do
    it "includes --session-id in help" do
      output = run_binary(["--help"])[:output]

      output.should contain("--session-id")
    end
  end
end

# Names what the whole file is about, across twenty-six examples. Everything
# else here calls run_binary directly.
def run_dryrun(persona : String, extra_args : Array(String) = [] of String) : String
  run_binary([persona, "--dry-run"] + extra_args)[:output]
end
