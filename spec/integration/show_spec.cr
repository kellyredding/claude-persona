require "../spec_helper"

describe "show integration" do
  describe "--json" do
    it "reports a persona's opening message" do
      result = run_binary(["show", "test-with-initial-message", "--json"])

      result[:status].should eq(0)
      report = JSON.parse(result[:output])
      report["name"].should eq("test-with-initial-message")
      report["initial_message"].should eq("Start your task now.")
      report["system_prompt"].should eq("You are a test assistant.")
      report["permission_mode"].should eq("default")
    end

    it "reports null for a persona with no opening message or prompt" do
      report = JSON.parse(run_binary(["show", "test-basic", "--json"])[:output])

      report["initial_message"].raw.should be_nil
      report["system_prompt"].raw.should be_nil
      report["effort"].raw.should be_nil
    end

    it "reports lists as arrays, empty when the persona sets none" do
      report = JSON.parse(run_binary(["show", "test-basic", "--json"])[:output])

      report["directories"].as_a.should be_empty
      report["mcp_configs"].as_a.should be_empty
      report["tools"]["allowed"].as_a.should be_empty
      report["tools"]["disallowed"].as_a.should be_empty
    end

    it "still prints the raw TOML without --json" do
      output = run_binary(["show", "test-basic"])[:output]

      output.should contain(%(description = "Basic test persona"))
    end

    it "errors for an unknown persona" do
      result = run_binary(["show", "no-such-persona", "--json"])

      result[:status].should eq(1)
      result[:error].should contain("Persona 'no-such-persona' not found")
    end
  end
end
