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
  end
end
