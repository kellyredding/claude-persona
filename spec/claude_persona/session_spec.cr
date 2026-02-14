require "../spec_helper"

describe ClaudePersona::Session do
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
