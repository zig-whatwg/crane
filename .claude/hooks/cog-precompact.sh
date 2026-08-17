#!/bin/sh
set -eu

# PreCompact hook: output concise Cog workflow carry-forward text.
# Claude appends stdout from PreCompact hooks into compaction instructions,
# so the compacted summary preserves Cog operational context.

has_cog_dir=false
if [ -d ".cog" ]; then
  has_cog_dir=true
fi

# Skip if no .cog directory — Cog is not configured
if [ "$has_cog_dir" = false ]; then
  exit 0
fi

has_memory=false
if [ -f ".cog/config.json" ] || [ -f ".cog/brain.db" ]; then
  has_memory=true
fi

has_index=false
if [ -f ".cog/index.scip" ]; then
  has_index=true
fi

# Check for active debug sessions via the daemon socket
has_debug=false
if [ -S ".cog/debug.sock" ]; then
  has_debug=true
fi

# Build carry-forward text
printf '%s\n' '[Cog compact carry-forward]'
if [ "$has_memory" = true ]; then
  printf '%s\n' '- Cog memory is available. Delegate to cog-mem sub-agent before broad code exploration.'
fi
if [ "$has_index" = true ]; then
  printf '%s\n' '- Cog code intelligence is available via code_explore and code_query.'
fi
if [ "$has_debug" = true ]; then
  printf '%s\n' '- A Cog debug daemon is running. Check for active debug sessions and stop them when done.'
fi
printf '%s\n' '- Load the cog-explore skill before code-intelligence calls and the cog-remember skill before memory writes.'
printf '%s\n' '- If Cog code tools were used, ensure durable findings are stored via cog-mem-validate before finishing.'

exit 0
