require "../spec_helper"

describe "track-session" do
  it "writes session_id from stdin JSON to output file" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    input = %({"session_id":"abc-123-def","source":"startup"})
    status = Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new(input),
      output: Process::Redirect::Close,
      error: Process::Redirect::Close,
    )

    status.success?.should be_true
    File.read(output_path).should eq("abc-123-def")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "overwrites file on subsequent calls" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    # First write
    input1 = %({"session_id":"first-id"})
    Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new(input1),
      output: Process::Redirect::Close,
      error: Process::Redirect::Close,
    )

    # Second write (simulates /clear)
    input2 = %({"session_id":"second-id"})
    Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new(input2),
      output: Process::Redirect::Close,
      error: Process::Redirect::Close,
    )

    File.read(output_path).should eq("second-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "shows usage when called without output file" do
    error = ""
    status = Process.run(
      "build/claude-persona",
      ["track-session"],
      input: IO::Memory.new("{}"),
      output: Process::Redirect::Close,
      error: :pipe,
    ) do |process|
      error = process.error.gets_to_end
    end

    error.should contain("Usage:")
    error.should contain("Example:")
    error.should contain("Settings injected via --settings:")
    error.should contain("SessionStart")
  end

  it "exits 0 silently on empty stdin" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    # Pre-write a value to verify it's NOT overwritten
    File.write(output_path, "original-id")

    error_io = IO::Memory.new
    status = Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new(""),
      output: Process::Redirect::Close,
      error: error_io,
    )

    status.success?.should be_true
    error_io.to_s.should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "exits 0 silently on invalid JSON" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    File.write(output_path, "original-id")

    error_io = IO::Memory.new
    status = Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new("not json"),
      output: Process::Redirect::Close,
      error: error_io,
    )

    status.success?.should be_true
    error_io.to_s.should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end

  it "exits 0 silently when session_id missing from JSON" do
    tempfile = File.tempfile("track-session-spec")
    tempfile.close
    output_path = tempfile.path

    File.write(output_path, "original-id")

    error_io = IO::Memory.new
    status = Process.run(
      "build/claude-persona",
      ["track-session", output_path],
      input: IO::Memory.new(%({"source":"startup"})),
      output: Process::Redirect::Close,
      error: error_io,
    )

    status.success?.should be_true
    error_io.to_s.should be_empty
    File.read(output_path).should eq("original-id")
  ensure
    File.delete(output_path) if output_path && File.exists?(output_path)
  end
end
