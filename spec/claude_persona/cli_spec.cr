require "../spec_helper"

describe ClaudePersona::CLI do
  describe "RESERVED_NAMES" do
    it "includes all subcommand names" do
      ClaudePersona::CLI::RESERVED_NAMES.should contain("list")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("generate")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("show")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("rename")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("remove")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("mcp")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("update")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("help")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("version")
    end
  end

  describe ".command_exists?" do
    it "returns true for commands that exist" do
      command_exists?("bash").should be_true
      command_exists?("curl").should be_true
    end

    it "returns false for commands that don't exist" do
      command_exists?("nonexistent-command-abc123").should be_false
    end
  end

  describe ".exit_code_for" do
    it "returns the exit code of a child that exited" do
      status = Process.run("sh", args: ["-c", "exit 3"])
      ClaudePersona::CLI.exit_code_for(status).should eq(3)
    end

    it "returns 0 for a child that succeeded" do
      status = Process.run("sh", args: ["-c", "exit 0"])
      ClaudePersona::CLI.exit_code_for(status).should eq(0)
    end

    it "returns 128 + the signal number for a child killed by a signal" do
      status = Process.run("sh", args: ["-c", "kill -TERM $$"])
      ClaudePersona::CLI.exit_code_for(status).should eq(128 + Signal::TERM.value)
    end
  end
end

describe "persona name validation" do
  describe "valid persona names" do
    it "accepts lowercase letters" do
      "railsdev".matches?(/^[a-zA-Z0-9_-]+$/).should be_true
    end

    it "accepts hyphens" do
      "rails-dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_true
    end

    it "accepts underscores" do
      "rails_dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_true
    end

    it "accepts numbers" do
      "rails-dev-2".matches?(/^[a-zA-Z0-9_-]+$/).should be_true
    end

    it "accepts mixed case" do
      "RailsDev".matches?(/^[a-zA-Z0-9_-]+$/).should be_true
    end
  end

  describe "invalid persona names" do
    it "rejects spaces" do
      "rails dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_false
    end

    it "rejects dots" do
      "rails.dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_false
    end

    it "rejects slashes" do
      "rails/dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_false
    end

    it "rejects special characters" do
      "rails@dev".matches?(/^[a-zA-Z0-9_-]+$/).should be_false
    end
  end

  describe "reserved persona names" do
    it "rejects 'list'" do
      ClaudePersona::CLI::RESERVED_NAMES.includes?("list").should be_true
    end

    it "rejects 'generate'" do
      ClaudePersona::CLI::RESERVED_NAMES.includes?("generate").should be_true
    end

    it "rejects 'help'" do
      ClaudePersona::CLI::RESERVED_NAMES.includes?("help").should be_true
    end

    it "rejects 'update'" do
      ClaudePersona::CLI::RESERVED_NAMES.includes?("update").should be_true
    end
  end
end

# Extract helper for testing (mirrors CLI.command_exists?)
def command_exists?(cmd : String) : Bool
  Process.run("which", args: [cmd], output: Process::Redirect::Close, error: Process::Redirect::Close).success?
end
