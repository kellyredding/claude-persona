require "../spec_helper"

describe ClaudePersona::SessionHookSettings do
  describe ".create" do
    it "creates both temp files" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid-123")

      File.exists?(settings_path).should be_true
      File.exists?(session_id_path).should be_true
    ensure
      ClaudePersona::SessionHookSettings.cleanup(settings_path, session_id_path)
    end

    it "writes valid JSON settings with SessionStart hook" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid-123")

      data = JSON.parse(File.read(settings_path.not_nil!))
      hooks = data["hooks"]["SessionStart"]
      hooks.as_a.size.should eq(1)

      command = hooks[0]["hooks"][0]["command"].as_s
      command.should contain("claude-persona track-session")
      command.should contain(session_id_path.not_nil!)
    ensure
      ClaudePersona::SessionHookSettings.cleanup(settings_path, session_id_path)
    end

    it "writes initial session ID to tracking file" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("initial-uuid")

      File.read(session_id_path.not_nil!).should eq("initial-uuid")
    ensure
      ClaudePersona::SessionHookSettings.cleanup(settings_path, session_id_path)
    end

    it "uses command type for hook" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid")

      data = JSON.parse(File.read(settings_path.not_nil!))
      hook_type = data["hooks"]["SessionStart"][0]["hooks"][0]["type"].as_s
      hook_type.should eq("command")
    ensure
      ClaudePersona::SessionHookSettings.cleanup(settings_path, session_id_path)
    end
  end

  describe ".read_session_id" do
    it "reads session ID from file" do
      tempfile = File.tempfile("test-session-id")
      tempfile.print("abc-123")
      tempfile.close

      result = ClaudePersona::SessionHookSettings.read_session_id(tempfile.path)
      result.should eq("abc-123")
    ensure
      File.delete(tempfile.not_nil!.path) if File.exists?(tempfile.not_nil!.path)
    end

    it "returns nil for missing file" do
      result = ClaudePersona::SessionHookSettings.read_session_id("/tmp/nonexistent-file")
      result.should be_nil
    end

    it "returns nil for empty file" do
      tempfile = File.tempfile("test-session-id")
      tempfile.close

      result = ClaudePersona::SessionHookSettings.read_session_id(tempfile.path)
      result.should be_nil
    ensure
      File.delete(tempfile.not_nil!.path) if File.exists?(tempfile.not_nil!.path)
    end

    it "strips whitespace from session ID" do
      tempfile = File.tempfile("test-session-id")
      tempfile.print("  abc-123  \n")
      tempfile.close

      result = ClaudePersona::SessionHookSettings.read_session_id(tempfile.path)
      result.should eq("abc-123")
    ensure
      File.delete(tempfile.not_nil!.path) if File.exists?(tempfile.not_nil!.path)
    end
  end

  describe ".example_settings_json" do
    it "returns valid JSON" do
      json = ClaudePersona::SessionHookSettings.example_settings_json
      data = JSON.parse(json)

      data["hooks"]["SessionStart"].as_a.size.should eq(1)
    end

    it "includes command type and placeholder" do
      json = ClaudePersona::SessionHookSettings.example_settings_json
      data = JSON.parse(json)

      hook = data["hooks"]["SessionStart"][0]["hooks"][0]
      hook["type"].as_s.should eq("command")
      hook["command"].as_s.should contain("claude-persona track-session")
      hook["command"].as_s.should contain("<output-file>")
    end
  end

  describe ".cleanup" do
    it "removes both files" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid")

      File.exists?(settings_path).should be_true
      File.exists?(session_id_path).should be_true

      ClaudePersona::SessionHookSettings.cleanup(settings_path, session_id_path)

      File.exists?(settings_path).should be_false
      File.exists?(session_id_path).should be_false
    end

    it "handles already-deleted files gracefully" do
      ClaudePersona::SessionHookSettings.cleanup(
        "/tmp/nonexistent-settings",
        "/tmp/nonexistent-session-id",
      )
      # Should not raise
    end

    it "handles nil settings_path" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid")

      ClaudePersona::SessionHookSettings.cleanup(nil, session_id_path)

      File.exists?(settings_path).should be_true
      File.exists?(session_id_path).should be_false
    ensure
      File.delete(settings_path.not_nil!) if settings_path && File.exists?(settings_path.not_nil!)
    end

    it "handles nil session_id_path" do
      settings_path, session_id_path = ClaudePersona::SessionHookSettings.create("test-uuid")

      ClaudePersona::SessionHookSettings.cleanup(settings_path, nil)

      File.exists?(settings_path).should be_false
      File.exists?(session_id_path).should be_true
    ensure
      File.delete(session_id_path.not_nil!) if session_id_path && File.exists?(session_id_path.not_nil!)
    end

    it "handles both nil" do
      ClaudePersona::SessionHookSettings.cleanup(nil, nil)
      # Should not raise
    end
  end
end
