require "../spec_helper"

describe "track-session" do
  it "writes session_id from stdin JSON to output file" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    result = run_binary(
      ["track-session", output_path],
      stdin: %({"session_id":"abc-123-def","source":"startup"}),
    )

    result[:status].should eq(0)
    File.read(output_path).should eq("abc-123-def")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "overwrites file on subsequent calls" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    run_binary(
      ["track-session", output_path],
      stdin: %({"session_id":"first-id"}),
    )

    # Second write (simulates /clear)
    run_binary(
      ["track-session", output_path],
      stdin: %({"session_id":"second-id"}),
    )

    File.read(output_path).should eq("second-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "shows usage when called without output file" do
    result = run_binary(["track-session"], stdin: "{}")

    result[:error].should contain("Usage:")
    result[:error].should contain("Example:")
    result[:error].should contain("Settings injected via --settings:")
    result[:error].should contain("SessionStart")
  end

  it "exits 0 silently on empty stdin" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    # Pre-write a value to verify it's NOT overwritten
    File.write(output_path, "original-id")

    result = run_binary(["track-session", output_path], stdin: "")

    result[:status].should eq(0)
    result[:error].should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "exits 0 silently on invalid JSON" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    File.write(output_path, "original-id")

    result = run_binary(["track-session", output_path], stdin: "not json")

    result[:status].should eq(0)
    result[:error].should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "exits 0 silently when session_id missing from JSON" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    File.write(output_path, "original-id")

    result = run_binary(
      ["track-session", output_path],
      stdin: %({"source":"startup"}),
    )

    result[:status].should eq(0)
    result[:error].should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end
end
