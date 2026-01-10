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

    it "includes --resume with session id" do
      output = run_dryrun("test-basic", ["--resume", "abc-123-def"])

      output.should contain("--resume")
      output.should contain("abc-123-def")
    end

    it "combines --vibe and --resume" do
      output = run_dryrun("test-basic", ["--vibe", "--resume", "abc-123"])

      output.should contain("--dangerously-skip-permissions")
      output.should contain("--resume")
      output.should contain("abc-123")
    end

    it "expands ~ in directory paths" do
      output = run_dryrun("test-full")

      output.should_not contain("~/")
      output.should match(/--add-dir \//)
    end
  end

  describe "generate command" do
    it "outputs claude command for generate" do
      output = run_generate_dryrun

      output.should contain("claude")
      output.should contain("--system-prompt")
      output.should contain("--add-dir")
      output.should contain("--allowed-tools")
    end
  end
end

def run_dryrun(persona : String, extra_args : Array(String) = [] of String) : String
  args = [persona, "--dry-run"] + extra_args

  # Run binary with test fixtures directory
  env = {"CLAUDE_PERSONA_CONFIG_DIR" => SPEC_FIXTURES.to_s}
  Process.run("build/claude-persona", args, env: env, output: :pipe, error: :pipe) do |process|
    process.output.gets_to_end
  end
end

def run_generate_dryrun : String
  env = {"CLAUDE_PERSONA_CONFIG_DIR" => SPEC_FIXTURES.to_s}
  Process.run("build/claude-persona", ["generate", "--dry-run"], env: env, output: :pipe, error: :pipe) do |process|
    process.output.gets_to_end
  end
end
