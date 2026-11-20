module ClaudePersona
  # Every launch replaces this process with claude instead of running it as a
  # child, so a host that terminates the session signals claude itself.
  module ClaudeExec
    def self.exec(args : Array(String)) : NoReturn
      # exec skips at_exit, so a partial line still buffered would be lost.
      STDOUT.flush
      STDERR.flush
      # Crystal ignores SIGPIPE at startup, and an ignored signal survives exec.
      Signal::PIPE.reset
      Process.exec("claude", args)
    end
  end
end
