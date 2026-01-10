require "../spec_helper"

describe ClaudePersona::CLI do
  describe "RESERVED_NAMES" do
    it "includes all subcommand names" do
      ClaudePersona::CLI::RESERVED_NAMES.should contain("list")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("generate")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("show")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("rename")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("mcp")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("help")
      ClaudePersona::CLI::RESERVED_NAMES.should contain("version")
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
  end
end
