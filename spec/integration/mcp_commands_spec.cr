require "../spec_helper"

describe "mcp available command" do
  it "lists user-scope MCPs with file path" do
    output = run_binary(["mcp", "available"])[:output]

    output.should contain("User scope")
    output.should contain("user-claude.json")
    output.should contain("user-mcp-http (http)")
    output.should contain("user-mcp-stdio (stdio)")
  end

  it "lists project-scope MCPs with file path" do
    output = run_binary(["mcp", "available"])[:output]

    output.should contain("Project scope")
    output.should contain("project-claude.json")
    output.should contain("project-mcp-sse (sse)")
  end

  it "shows both scopes always" do
    output = run_binary(["mcp", "available"])[:output]

    output.should contain("User scope")
    output.should contain("Project scope")
  end
end

describe "mcp list command" do
  it "lists imported MCP configs" do
    output = run_binary(["mcp", "list"])[:output]

    # test-mcp.json exists in fixtures
    output.should contain("test-mcp")
  end
end

describe "mcp show command" do
  it "displays imported MCP config JSON" do
    output = run_binary(["mcp", "show", "test-mcp"])[:output]

    output.should contain("mcpServers")
    output.should contain("test-mcp")
  end
end
