require "../spec_helper"

describe ClaudePersona::Error do
  it "is the base every anticipated failure descends from" do
    # The point of the base class: CLI.guard rescues it alone and still
    # covers each specific failure below it.
    ClaudePersona::PersonaNotFound
      .new("missing", Path["/tmp/missing.toml"])
      .should be_a(ClaudePersona::Error)

    ClaudePersona::McpConfigNotFound
      .new("missing", Path["/tmp/missing.json"])
      .should be_a(ClaudePersona::Error)
  end

  it "builds its own message from the values it was given" do
    error = ClaudePersona::PersonaNotFound.new("rails-dev", Path["/tmp/x.toml"])

    error.message.should eq("Persona 'rails-dev' not found at /tmp/x.toml")
  end
end
