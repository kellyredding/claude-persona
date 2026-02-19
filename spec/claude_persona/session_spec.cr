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

  describe "#format_duration" do
    it "formats seconds only" do
      duration = Time::Span.new(seconds: 45)
      result = format_duration(duration)
      result.should eq("45s")
    end

    it "formats minutes and seconds" do
      duration = Time::Span.new(minutes: 5, seconds: 30)
      result = format_duration(duration)
      result.should eq("5m 30s")
    end

    it "formats hours, minutes, and seconds" do
      duration = Time::Span.new(hours: 2, minutes: 15, seconds: 45)
      result = format_duration(duration)
      result.should eq("2h 15m 45s")
    end

    it "handles zero duration" do
      duration = Time::Span.new(seconds: 0)
      result = format_duration(duration)
      result.should eq("0s")
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

def format_duration(duration : Time::Span) : String
  total_seconds = duration.total_seconds.to_i
  hours = total_seconds // 3600
  minutes = (total_seconds % 3600) // 60
  seconds = total_seconds % 60

  if hours > 0
    "#{hours}h #{minutes}m #{seconds}s"
  elsif minutes > 0
    "#{minutes}m #{seconds}s"
  else
    "#{seconds}s"
  end
end
