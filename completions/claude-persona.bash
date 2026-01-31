# Bash completion for claude-persona
# https://github.com/kellyredding/claude-persona
#
# Installation:
#   source /path/to/claude-persona.bash
#
# Or copy to your bash-completion directory:
#   cp claude-persona.bash /etc/bash_completion.d/claude-persona
#   cp claude-persona.bash /usr/local/etc/bash_completion.d/claude-persona  # macOS with Homebrew
#
# If you use an alias, add completion for it too:
#   alias persona='claude-persona'
#   complete -F _claude_persona persona

_claude_persona() {
    local cur prev words cword
    _init_completion || return

    local commands="list generate show rename remove update mcp help version"
    local mcp_commands="available list import import-all show remove"
    local update_commands="preview force help"
    local global_opts="--vibe --dangerously-skip-permissions --dry-run --resume --help --version -r -h -v"

    # Get persona names dynamically
    _claude_persona_personas() {
        claude-persona list 2>/dev/null | grep -E '^  [a-zA-Z0-9_-]+ \(' | sed 's/^  //' | cut -d' ' -f1
    }

    # Get imported MCP config names dynamically
    _claude_persona_mcps() {
        claude-persona mcp list 2>/dev/null | grep -E '^  [a-zA-Z0-9_-]+ \(' | sed 's/^  //' | cut -d' ' -f1
    }

    # Get available MCP names to import dynamically
    _claude_persona_mcps_available() {
        claude-persona mcp available 2>/dev/null | grep -E '^  [a-zA-Z0-9_-]+ \(' | sed 's/^  //' | cut -d' ' -f1
    }

    case "${cword}" in
        1)
            # First argument: commands or persona names or global flags
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
            else
                local personas=$(_claude_persona_personas)
                COMPREPLY=($(compgen -W "${commands} ${personas}" -- "${cur}"))
            fi
            ;;
        2)
            case "${prev}" in
                show|remove)
                    # These commands take a persona name
                    local personas=$(_claude_persona_personas)
                    COMPREPLY=($(compgen -W "${personas}" -- "${cur}"))
                    ;;
                rename)
                    # First arg to rename is existing persona name
                    local personas=$(_claude_persona_personas)
                    COMPREPLY=($(compgen -W "${personas}" -- "${cur}"))
                    ;;
                mcp)
                    # MCP subcommands
                    COMPREPLY=($(compgen -W "${mcp_commands}" -- "${cur}"))
                    ;;
                update)
                    # Update subcommands
                    COMPREPLY=($(compgen -W "${update_commands}" -- "${cur}"))
                    ;;
                --resume|-r)
                    # Session ID - no completion available
                    COMPREPLY=()
                    ;;
                list|generate|help|version)
                    # These don't take arguments, offer flags
                    if [[ "${cur}" == -* ]]; then
                        COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
                    fi
                    ;;
                *)
                    # Could be a persona name followed by flags
                    if [[ "${cur}" == -* ]]; then
                        COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
                    fi
                    ;;
            esac
            ;;
        3)
            # Third position depends on context
            local cmd="${words[1]}"
            local subcmd="${words[2]}"

            case "${cmd}" in
                mcp)
                    case "${subcmd}" in
                        show|remove)
                            # mcp show/remove take imported MCP names
                            local mcps=$(_claude_persona_mcps)
                            COMPREPLY=($(compgen -W "${mcps}" -- "${cur}"))
                            ;;
                        import)
                            # mcp import takes available MCP names
                            local mcps=$(_claude_persona_mcps_available)
                            COMPREPLY=($(compgen -W "${mcps}" -- "${cur}"))
                            ;;
                        *)
                            if [[ "${cur}" == -* ]]; then
                                COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
                            fi
                            ;;
                    esac
                    ;;
                rename)
                    # Second arg to rename is new name - no completion
                    COMPREPLY=()
                    ;;
                *)
                    # Likely flags after persona name or command
                    if [[ "${cur}" == -* ]]; then
                        COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
                    fi
                    ;;
            esac
            ;;
        *)
            # Fourth position and beyond - just offer flags
            if [[ "${cur}" == -* ]]; then
                COMPREPLY=($(compgen -W "${global_opts}" -- "${cur}"))
            fi
            ;;
    esac
}

complete -F _claude_persona claude-persona
