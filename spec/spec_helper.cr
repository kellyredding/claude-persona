require "spec"
require "file_utils"

# The fixture tree is a read-only master. Specs run against a copy in a
# temporary directory rather than pointing the binary at the checked-in files
# directly: launching a persona rewrites any file whose version is behind the
# binary, so a suite aimed at the fixtures themselves would mutate tracked
# files the moment those two disagreed.
SPEC_FIXTURES        = Path[__DIR__] / "fixtures"
SPEC_CLAUDE_FIXTURES = SPEC_FIXTURES / "claude"

SPEC_CONFIG_DIR = Path.new(Dir.tempdir) /
                  "claude-persona-test-#{Random.rand(100000)}"

def seed_spec_config_dir
  FileUtils.rm_rf(SPEC_CONFIG_DIR.to_s)
  Dir.mkdir_p(SPEC_CONFIG_DIR.to_s)
  FileUtils.cp_r(
    (SPEC_FIXTURES / "personas").to_s,
    (SPEC_CONFIG_DIR / "personas").to_s,
  )
  FileUtils.cp_r(
    (SPEC_FIXTURES / "mcp").to_s,
    (SPEC_CONFIG_DIR / "mcp").to_s,
  )
end

seed_spec_config_dir

# Set before requiring the module: CONFIG_DIR is a constant, so it is
# evaluated once at require time and cannot pick these up afterwards.
ENV["CLAUDE_PERSONA_CONFIG_DIR"] = SPEC_CONFIG_DIR.to_s
ENV["CLAUDE_USER_CONFIG_PATH"] = (SPEC_CLAUDE_FIXTURES / "user-claude.json").to_s
ENV["CLAUDE_PROJECT_CONFIG_PATH"] = (SPEC_CLAUDE_FIXTURES / "project-claude.json").to_s

# Skip CLI auto-run when loading module for specs
ENV["CLAUDE_PERSONA_SKIP_CLI"] = "1"

require "../src/claude_persona"

# Helper to read fixture files
def fixture_path(relative_path : String) : Path
  SPEC_FIXTURES / relative_path
end

def read_fixture(relative_path : String) : String
  File.read(fixture_path(relative_path))
end

# Helper for running the binary in integration tests
# __DIR__ is the spec/ directory, so we go up one level to find build/
BINARY_PATH = Path[__DIR__].parent / "build" / "claude-persona"

def run_binary(
  args : Array(String) = [] of String,
  stdin : String? = nil,
  extra_env : Hash(String, String) = {} of String => String,
) : NamedTuple(output: String, error: String, status: Int32)
  unless File.exists?(BINARY_PATH)
    raise "Binary not found at #{BINARY_PATH}. Run 'make dev' first."
  end

  # Unset skip cli if it was set. Crystal merges `env` into the parent's
  # environment rather than replacing it, so leaving this set would reach
  # the binary under test and make it exit without running anything.
  ENV.delete("CLAUDE_PERSONA_SKIP_CLI")

  input_io : Process::Stdio = Process::Redirect::Close
  if stdin
    input_io = IO::Memory.new(stdin)
  end

  base_env = {
    "CLAUDE_PERSONA_CONFIG_DIR"  => SPEC_CONFIG_DIR.to_s,
    "CLAUDE_USER_CONFIG_PATH"    => (SPEC_CLAUDE_FIXTURES / "user-claude.json").to_s,
    "CLAUDE_PROJECT_CONFIG_PATH" => (SPEC_CLAUDE_FIXTURES / "project-claude.json").to_s,
    "HOME"                       => ENV["HOME"],
    "PATH"                       => ENV["PATH"],
  }
  merged_env = base_env.merge(extra_env)

  process = Process.new(
    BINARY_PATH.to_s,
    args: args,
    input: input_io,
    output: Process::Redirect::Pipe,
    error: Process::Redirect::Pipe,
    env: merged_env,
  )

  # Read output streams
  output_content = process.output.gets_to_end
  error_content = process.error.gets_to_end

  status = process.wait

  {
    output: output_content,
    error:  error_content,
    status: status.exit_code,
  }
end

# Run the binary against a throwaway config directory, for examples that need
# to observe what a command wrote rather than what the shared fixtures hold.
def with_temp_config_dir(&)
  temp_dir = Path[Dir.tempdir] / "claude-persona-test-#{Random.rand(100000)}"
  Dir.mkdir_p(temp_dir / "personas")
  Dir.mkdir_p(temp_dir / "mcp")

  begin
    yield temp_dir
  ensure
    FileUtils.rm_rf(temp_dir.to_s) if Dir.exists?(temp_dir)
  end
end

def run_with_temp_config(
  config_dir : Path,
  args : Array(String),
) : NamedTuple(output: String, error: String, status: Int32)
  run_binary(
    args,
    extra_env: {"CLAUDE_PERSONA_CONFIG_DIR" => config_dir.to_s},
  )
end

# Restore the copied fixtures between examples. A command that rewrites a
# persona would otherwise leave it rewritten for every example after it.
Spec.before_each do
  seed_spec_config_dir
end

Spec.after_suite do
  FileUtils.rm_rf(SPEC_CONFIG_DIR.to_s) if Dir.exists?(SPEC_CONFIG_DIR)
end
