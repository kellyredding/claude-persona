module ClaudePersona
  # Settings a host launching a persona passes on top of it. They land after
  # the persona's own flags, and claude takes the last --permission-mode and
  # adds up repeated --disallowed-tools, so a host's choice wins.
  record LaunchOverrides,
    permission_mode : String? = nil,
    disallowed_tools : Array(String) = [] of String,
    settings : String? = nil
end
