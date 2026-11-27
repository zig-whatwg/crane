#!/bin/sh
# Blocks any Agent or Workflow call that names a Fable model (the user, 2026-11-27 5:46 PM ET:
# "do not use fable at all, completely restrict the use of fable"). Opus is the top model here.
input=$(cat)
if printf '%s' "$input" | grep -qiE "model[\\\\\"']*[[:space:]]*:[[:space:]]*[\\\\\"']*[a-z0-9._-]*fable"; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Fable is banned in Crane (the user, 2026-11-27: do not use fable at all). Use model opus."}}'
fi
exit 0
