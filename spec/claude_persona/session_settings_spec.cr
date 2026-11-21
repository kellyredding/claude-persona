require "../spec_helper"

describe ClaudePersona::SessionSettings do
  describe ".json" do
    it "carries the session id as CLAUDE_CLI_SESSION_ID" do
      data = JSON.parse(ClaudePersona::SessionSettings.json("durable-uuid-456"))

      data["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should eq("durable-uuid-456")
    end

    it "installs no hooks" do
      data = JSON.parse(ClaudePersona::SessionSettings.json("test-uuid"))

      data.as_h.keys.should eq(["env"])
    end

    describe "with a host's settings" do
      it "keeps the host's hooks beside the session id" do
        host = %({"hooks":{"PermissionRequest":[{"hooks":[{"type":"command","command":"allow"}]}]}})
        data = JSON.parse(ClaudePersona::SessionSettings.json("sid-1", host))

        data["hooks"]["PermissionRequest"][0]["hooks"][0]["command"].as_s.should eq("allow")
        data["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should eq("sid-1")
      end

      it "keeps the host's other env alongside the session id" do
        host = %({"env":{"FOO":"bar"}})
        data = JSON.parse(ClaudePersona::SessionSettings.json("sid-1", host))

        data["env"]["FOO"].as_s.should eq("bar")
        data["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should eq("sid-1")
      end

      it "always sets the session id itself" do
        host = %({"env":{"CLAUDE_CLI_SESSION_ID":"host-value"}})
        data = JSON.parse(ClaudePersona::SessionSettings.json("sid-1", host))

        data["env"]["CLAUDE_CLI_SESSION_ID"].as_s.should eq("sid-1")
      end

      it "raises InvalidSettingsError for invalid JSON" do
        expect_raises(ClaudePersona::InvalidSettingsError, "--settings must be a JSON object") do
          ClaudePersona::SessionSettings.json("sid-1", "{not json")
        end
      end

      it "raises InvalidSettingsError for JSON that is not an object" do
        expect_raises(ClaudePersona::InvalidSettingsError, "--settings must be a JSON object") do
          ClaudePersona::SessionSettings.json("sid-1", "[1, 2]")
        end
      end
    end
  end

  describe ".host_json" do
    it "returns nil without host settings" do
      ClaudePersona::SessionSettings.host_json(nil).should be_nil
    end

    it "returns the host's settings without a session id" do
      data = JSON.parse(ClaudePersona::SessionSettings.host_json(%({"env":{"FOO":"bar"}})).not_nil!)

      data["env"]["FOO"].as_s.should eq("bar")
      data["env"]["CLAUDE_CLI_SESSION_ID"]?.should be_nil
    end

    it "raises InvalidSettingsError for invalid JSON" do
      expect_raises(ClaudePersona::InvalidSettingsError) do
        ClaudePersona::SessionSettings.host_json("nope")
      end
    end
  end
end
