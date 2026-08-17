#!/bin/sh
set -eu

payload=$(cat)

extract_string() {
  key=$1
  printf '%s' "$payload" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

transcript_has() {
  pattern=$1
  transcript_path=$2
  if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    return 1
  fi
  grep -q "$pattern" "$transcript_path"
}

if [ ! -f ".mcp.json" ] || ! grep -q '"cog"' ".mcp.json"; then
  exit 0
fi

tool_name=$(printf '%s' "$payload" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
transcript_path=$(extract_string transcript_path)

deny() {
  reason=$1
  printf '%s\n' "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$reason\"}}"
  exit 0
}

advise() {
  printf '%s\n' "$1" >&2
}

case "$tool_name" in
  Agent)
    # Extract subagent_type from tool_input
    subagent_type=$(printf '%s' "$payload" | sed -n 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

    case "$subagent_type" in
      cog-mem|cog-mem-validate)
        # Memory sub-agents are always allowed
        ;;
      Explore|cog-code-query)
        # Code exploration sub-agents must wait for memory recall
        if ! transcript_has 'mcp__cog__mem_recall' "$transcript_path" && \
           ! transcript_has '"subagent_type":"cog-mem"' "$transcript_path" && \
           ! transcript_has '"subagent_type": "cog-mem"' "$transcript_path"; then
          deny "Cog memory workflow: delegate to the cog-mem sub-agent first so it can check memory before launching code exploration. Launch cog-mem alone, wait for its result, then explore code only if memory was insufficient."
        fi
        ;;
    esac
    ;;
  mcp__cog__code_explore|mcp__cog__code_query)
    if ! transcript_has 'mcp__cog__mem_recall' "$transcript_path" && \
       ! transcript_has '"subagent_type":"cog-mem"' "$transcript_path" && \
       ! transcript_has '"subagent_type": "cog-mem"' "$transcript_path"; then
      deny "Cog memory workflow: delegate to the cog-mem sub-agent first to check memory before using code exploration tools. Memory may already have the answer."
    fi
    ;;
  Grep)
    deny "Use Cog code intelligence tools before raw text search when the Cog MCP server is configured."
    ;;
  mcp__cog__mem_*|cog_mem_*)
    if printf '%s' "$payload" | grep -Eq '"relation"[[:space:]]*:[[:space:]]*"related_to"'; then
      advise "Cog memory quality: prefer a stronger predicate than related_to when the relationship is directional or structural."
    fi
    if printf '%s' "$payload" | grep -Eq '"definition"[[:space:]]*:[[:space:]]*"[^"]{0,31}"'; then
      advise "Cog memory quality: this definition looks short. Include why the fact matters, not just the surface description."
    fi
    ;;
esac

exit 0
