module ClaudePersona
  # Base for every failure this tool anticipates and can describe in a
  # sentence: a persona that is not there, an MCP config that was never
  # imported, a file that will not parse.
  #
  # Descending from this is a claim that the message is fit to be the only
  # thing a user sees, and CLI.guard turns it into exactly that — one line and
  # a non-zero exit. Anything that does not descend from it is a defect, and
  # should surface as a crash with a backtrace rather than be flattened into
  # tidy prose that hides where it came from.
  class Error < Exception
  end

  class PersonaNotFound < Error
    def initialize(name : String, path : Path)
      super("Persona '#{name}' not found at #{path}")
    end
  end

  class McpConfigNotFound < Error
    def initialize(name : String, path : Path)
      super("MCP config '#{name}' not found at #{path}")
    end
  end
end
