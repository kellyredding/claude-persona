require "toml"
require "json"

module ClaudePersona
  struct PersonaConfig
    getter description : String
    getter model : String
    getter directories : DirectoriesConfig?
    getter mcp : McpConfig?
    getter tools : ToolsConfig?
    getter permissions : PermissionsConfig?
    getter prompt : PromptConfig?

    def initialize(table : TOML::Table)
      @description = table["description"]?.try(&.as_s) || ""
      @model = table["model"]?.try(&.as_s) || "sonnet"

      if dirs_table = table["directories"]?.try(&.as_h)
        @directories = DirectoriesConfig.new(dirs_table)
      end

      if mcp_table = table["mcp"]?.try(&.as_h)
        @mcp = McpConfig.new(mcp_table)
      end

      if tools_table = table["tools"]?.try(&.as_h)
        @tools = ToolsConfig.new(tools_table)
      end

      if perms_table = table["permissions"]?.try(&.as_h)
        @permissions = PermissionsConfig.new(perms_table)
      end

      if prompt_table = table["prompt"]?.try(&.as_h)
        @prompt = PromptConfig.new(prompt_table)
      end
    end

    def self.load(name : String) : PersonaConfig
      path = PERSONAS_DIR / "#{name}.toml"
      unless File.exists?(path)
        raise ConfigError.new("Persona '#{name}' not found at #{path}")
      end
      from_toml(File.read(path))
    end

    def self.from_toml(content : String) : PersonaConfig
      table = TOML.parse(content)
      new(table)
    end
  end

  struct DirectoriesConfig
    getter allowed : Array(String)

    def initialize(table : TOML::Table)
      @allowed = table["allowed"]?.try(&.as_a.map(&.as_s)) || [] of String
    end
  end

  struct McpConfig
    getter configs : Array(String)

    def initialize(table : TOML::Table)
      @configs = table["configs"]?.try(&.as_a.map(&.as_s)) || [] of String
    end
  end

  struct ToolsConfig
    getter allowed : Array(String)
    getter disallowed : Array(String)

    def initialize(table : TOML::Table)
      @allowed = table["allowed"]?.try(&.as_a.map(&.as_s)) || [] of String
      @disallowed = table["disallowed"]?.try(&.as_a.map(&.as_s)) || [] of String
    end
  end

  struct PermissionsConfig
    getter mode : String

    def initialize(table : TOML::Table)
      @mode = table["mode"]?.try(&.as_s) || "default"
    end
  end

  struct PromptConfig
    getter system : String

    def initialize(table : TOML::Table)
      @system = table["system"]?.try(&.as_s) || ""
    end
  end

  class ConfigError < Exception
  end
end
