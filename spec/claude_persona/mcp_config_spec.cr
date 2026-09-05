require "../spec_helper"

describe ClaudePersona::McpHandler do
  describe ".available_user_mcps" do
    it "returns MCPs from user-scope claude.json" do
      mcps = ClaudePersona::McpHandler.available_user_mcps

      mcps.has_key?("user-mcp-http").should be_true
      mcps.has_key?("user-mcp-stdio").should be_true

      mcps["user-mcp-http"]["type"].as_s.should eq("http")
      mcps["user-mcp-http"]["url"].as_s.should eq("https://example.com/mcp")

      mcps["user-mcp-stdio"]["type"].as_s.should eq("stdio")
      mcps["user-mcp-stdio"]["command"].as_s.should eq("npx")
    end
  end

  describe ".available_project_mcps" do
    it "returns MCPs from project-scope claude.json" do
      mcps = ClaudePersona::McpHandler.available_project_mcps

      mcps.has_key?("project-mcp-sse").should be_true

      mcps["project-mcp-sse"]["type"].as_s.should eq("sse")
      mcps["project-mcp-sse"]["url"].as_s.should eq("https://project.example.com/sse")
    end
  end

  describe ".list" do
    it "returns imported MCP config names" do
      mcps = ClaudePersona::McpHandler.list

      # test-mcp.json exists in fixtures/mcp/
      mcps.should contain("test-mcp")
    end
  end

  describe ".resolve_mcp_paths" do
    it "resolves MCP names to full paths" do
      paths = ClaudePersona::McpHandler.resolve_mcp_paths(["test-mcp"])

      paths.size.should eq(1)
      paths.first.should end_with("test-mcp.json")
    end

    it "raises McpConfigNotFound for missing MCP" do
      expect_raises(ClaudePersona::McpConfigNotFound, /not found/) do
        ClaudePersona::McpHandler.resolve_mcp_paths(["nonexistent"])
      end
    end
  end
end
