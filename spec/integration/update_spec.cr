require "../spec_helper"

describe "update integration" do
  describe "update help" do
    it "outputs help for 'update help' subcommand" do
      output = run_binary(["update", "help"])[:output]

      output.should contain("claude-persona update")
      output.should contain("Update to latest version")
      output.should contain("update preview")
      output.should contain("update force")
      output.should contain("update help")
      output.should contain("raw.githubusercontent.com")
    end
  end

  describe "main help includes update" do
    it "shows update commands in main help" do
      output = run_binary(["help"])[:output]

      output.should contain("update")
      output.should contain("Update to latest version")
      output.should contain("update preview")
      output.should contain("update force")
    end
  end
end
