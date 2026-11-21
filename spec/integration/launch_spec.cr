require "../spec_helper"

FAKE_CLAUDE_DIR = SPEC_FIXTURES / "bin"

record FakeClaudeRun,
  status : Int32,
  output : String,
  pid : Int64,
  ppid : Int64,
  args : Array(String),
  settings : String,
  sigpipe_probe : Int32

# Launches against the fake claude in spec/fixtures/bin. PATH holds only that
# directory and the system ones, so the real claude cannot be reached, and the
# fake's marker is required before anything else is read: a launch that
# reached some other claude fails here instead of passing.
def run_with_fake_claude(args : Array(String), exit_code : Int32 = 0) : FakeClaudeRun
  File.chmod(FAKE_CLAUDE_DIR / "claude", 0o755)
  record_dir = Path[Dir.tempdir] / "fake-claude-#{Random.rand(1_000_000)}"
  marker = Path[Dir.tempdir] / "fake-claude-#{Random.rand(1_000_000)}.marker"

  begin
    result = run_binary(
      args,
      extra_env: {
        "PATH"               => "#{FAKE_CLAUDE_DIR}:/usr/bin:/bin",
        "FAKE_CLAUDE_OUT"    => record_dir.to_s,
        "FAKE_CLAUDE_MARKER" => marker.to_s,
        "FAKE_CLAUDE_EXIT"   => exit_code.to_s,
      },
    )

    File.exists?(marker).should be_true

    FakeClaudeRun.new(
      status: result[:status],
      output: result[:output],
      pid: File.read(record_dir / "pid").strip.to_i64,
      ppid: File.read(record_dir / "ppid").strip.to_i64,
      args: File.read(record_dir / "args").split('\0', remove_empty: true),
      settings: File.read(record_dir / "settings"),
      sigpipe_probe: File.read(record_dir / "sigpipe").strip.to_i,
    )
  ensure
    FileUtils.rm_rf(record_dir.to_s)
    File.delete(marker) if File.exists?(marker)
  end
end

describe "launch" do
  describe "interactive persona" do
    it "replaces itself with claude" do
      run = run_with_fake_claude(["test-basic"])

      run.ppid.should eq(Process.pid)
    end

    it "exits with claude's exit status" do
      run = run_with_fake_claude(["test-basic"], exit_code: 7)

      run.status.should eq(7)
    end

    it "keeps the launch banner written before claude replaces it" do
      run = run_with_fake_claude(["test-basic"])

      run.output.should contain("Launching persona: test-basic")
    end

    it "gives claude the default SIGPIPE disposition" do
      run = run_with_fake_claude(["test-basic"])

      # The fake's probe: 141 when a writer dies of SIGPIPE, 1 when it is ignored.
      run.sigpipe_probe.should eq(141)
    end

    it "passes the session id to claude in inline settings" do
      session_id = "aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee"
      run = run_with_fake_claude(["test-basic", "--session-id", session_id])

      settings = JSON.parse(run.settings)
      settings["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should eq(session_id)
    end

    it "hands claude a host's overrides after the persona's flags" do
      host = %({"hooks":{"PermissionRequest":[{"hooks":[{"type":"command","command":"allow"}]}]}})
      run = run_with_fake_claude([
        "test-full", "--vibe",
        "--disallowed-tools", "AskUserQuestion,EnterPlanMode",
        "--settings", host,
      ])

      last = run.args.rindex("--disallowed-tools").not_nil!
      last.should be > run.args.index("--disallowed-tools").not_nil!
      run.args[last + 1, 2].should eq(["AskUserQuestion", "EnterPlanMode"])

      settings = JSON.parse(run.settings)
      settings["hooks"]["PermissionRequest"][0]["hooks"][0]["command"].as_s.should eq("allow")
      settings["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should_not be_empty
    end
  end

  describe "print mode" do
    it "replaces itself with claude and exits with its status" do
      run = run_with_fake_claude(["test-basic", "-p", "Hello"], exit_code: 3)

      run.ppid.should eq(Process.pid)
      run.status.should eq(3)
      run.args.should contain("--print")
      run.args.should_not contain("--settings")
    end
  end

  describe "generate" do
    it "replaces itself with claude" do
      run = run_with_fake_claude(["generate"])

      run.ppid.should eq(Process.pid)
      run.output.should contain("Claude Persona Generator")
    end
  end
end
