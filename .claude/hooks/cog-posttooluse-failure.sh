#!/bin/sh
set -eu

payload=$(cat)

# Only act on Cog MCP tool failures
tool_name=$(printf '%s' "$payload" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
error_text=$(printf '%s' "$payload" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

case "$tool_name" in
  mcp__cog__*) ;;
  *) exit 0 ;;
esac

guidance=""

case "$tool_name" in
  mcp__cog__code_explore|mcp__cog__code_query)
    case "$error_text" in
      *[Ii]ndex[Uu]navail*|*"no index"*|*"index unavailable"*)
        guidance="The SCIP code index is not available. Run cog code:index in a terminal to build it, or fall back to Read and Glob tools for file-based exploration."
        ;;
      *"not found"*|*"Symbol not found"*)
        guidance="The symbol was not found in the code index. Try alternative names, broader glob patterns (e.g. *init*), or fall back to Grep for text-based search."
        ;;
      *)
        guidance="Code intelligence tool failed. Try the operation once more. If it fails again, fall back to Read and Grep for file-based exploration."
        ;;
    esac
    ;;
  mcp__cog__mem_*)
    case "$error_text" in
      *[Nn]ot[Cc]onfigured*|*"not configured"*)
        guidance="Cog memory is not configured for this project. Proceed without memory. The user can run cog init to enable it later."
        ;;
      *"failed to open"*|*"connection"*|*ECONNREFUSED*|*"unreachable"*)
        guidance="The Cog memory backend is temporarily unreachable. Proceed without memory for now. It may recover on subsequent calls."
        ;;
      *)
        guidance="Memory tool failed. Try once more. If it fails again, proceed without memory for this task."
        ;;
    esac
    ;;
  mcp__cog__debug_*)
    case "$error_text" in
      *"session not found"*|*"no active session"*)
        guidance="The debug session is no longer active. It may have timed out. Start a new session with debug_launch if debugging is still needed."
        ;;
      *"adapter"*|*"launch failed"*)
        guidance="The debug adapter failed to start. Check that the required debugger is installed (e.g. debugpy for Python, delve for Go). Consider inspecting the code statically instead."
        ;;
      *)
        guidance="Debug tool failed. Try once more. If it fails again, consider a different debugging approach or static code inspection."
        ;;
    esac
    ;;
esac

if [ -n "$guidance" ]; then
  # Escape quotes for JSON
  guidance_escaped=$(printf '%s' "$guidance" | sed 's/"/\\"/g')
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUseFailure","additionalContext":"%s"}}\n' "$guidance_escaped"
fi

exit 0
