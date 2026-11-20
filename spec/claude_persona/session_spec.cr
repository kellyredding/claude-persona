require "../spec_helper"

describe ClaudePersona::Session do
  describe "#initialize" do
    it "generates a UUID when no session IDs are provided" do
      config = session_minimal_config
      session = ClaudePersona::Session.new("test", config)

      session.session_id.should match(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/)
    end

    it "uses resume_session_id when provided" do
      config = session_minimal_config
      session = ClaudePersona::Session.new("test", config, "resume-uuid-123")

      session.session_id.should eq("resume-uuid-123")
    end

    it "uses cli_session_id when provided" do
      config = session_minimal_config
      session = ClaudePersona::Session.new("test", config, cli_session_id: "injected-uuid-456")

      session.session_id.should eq("injected-uuid-456")
    end

    it "prioritizes resume_session_id over cli_session_id" do
      config = session_minimal_config
      session = ClaudePersona::Session.new("test", config, "resume-uuid", cli_session_id: "injected-uuid")

      session.session_id.should eq("resume-uuid")
    end
  end
end

def session_minimal_config : ClaudePersona::PersonaConfig
  ClaudePersona::PersonaConfig.from_toml(<<-TOML
  description = "Test"
  model = "sonnet"
  TOML
  )
end
