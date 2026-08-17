#!/bin/sh
set -eu

payload=$(cat)

extract_bool() {
  key=$1
  printf '%s' "$payload" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p" | head -n 1
}

extract_string() {
  key=$1
  printf '%s' "$payload" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

transcript_has() {
  pattern=$1
  grep -q "$pattern" "$transcript_path"
}

stop_hook_active=$(extract_bool stop_hook_active)
transcript_path=$(extract_string transcript_path)

if [ "$stop_hook_active" = "true" ]; then
  exit 0
fi

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  exit 0
fi

# If cog-mem-validate subagent was already delegated to, it owns the full
# learn-and-consolidate lifecycle. Accept and exit.
if transcript_has 'cog-mem-validate'; then
  exit 0
fi

used_recall=false
if transcript_has 'mcp__cog__mem_recall'; then
  used_recall=true
fi

used_explore=false
if transcript_has 'mcp__cog__code_explore' || transcript_has 'mcp__cog__code_query'; then
  used_explore=true
fi

if [ "$used_explore" = true ] && [ "$used_recall" = false ]; then
  printf '%s\n' 'You used cog_code_explore without checking Cog memory first. If prior knowledge might help, call cog_mem_recall before responding.' >&2
  exit 2
fi

# If explore was used but no memory was written and no cog-mem delegation
# happened, the agent should delegate to cog-mem-validate to learn + consolidate
# in a single subagent call.
wrote_memory=false
if transcript_has 'mcp__cog__mem_learn' || \
   transcript_has 'mcp__cog__mem_associate' || \
   transcript_has 'mcp__cog__mem_refactor' || \
   transcript_has 'mcp__cog__mem_update' || \
   transcript_has 'mcp__cog__mem_deprecate'; then
  wrote_memory=true
fi

if [ "$used_explore" = true ] && [ "$wrote_memory" = false ]; then
  printf '%s\n' 'Delegate to the cog-mem-validate sub-agent to learn durable knowledge from this exploration and consolidate short-term memories. One subagent call — do not call memory tools directly.' >&2
  exit 2
fi

# If memory was written directly (not via cog-mem-validate), require consolidation
if [ "$wrote_memory" = true ]; then
  consolidated=false
  if transcript_has 'mcp__cog__mem_list_short_term' || \
     transcript_has 'mcp__cog__mem_reinforce' || \
     transcript_has 'mcp__cog__mem_verify' || \
     transcript_has 'mcp__cog__mem_flush'; then
    consolidated=true
  fi

  if [ "$consolidated" = false ]; then
    printf '%s\n' 'Delegate to the cog-mem-validate sub-agent to consolidate short-term memories before finishing. One subagent call — do not call memory tools directly.' >&2
    exit 2
  fi
fi

exit 0
