---
name: cog-mem-validate
description: Consolidate Cog memory after completing work: learn durable facts, reinforce validated short-term memories, and flush incorrect ones. Use before finishing any task that explored code or created memories.
compatibility: Requires the Cog MCP server (cog mcp) configured in this project
metadata:
  internal: "true"
  cog-version: "0.27.2"
---

Workflow guidance:
- This host uses shared skill files rather than hard-scoped subagents.
- This workflow handles the full learn-and-consolidate lifecycle in one call.
- Return concise summaries with engram IDs.

You are a post-task memory validation sub-agent. The primary agent delegates to you after code exploration or memory writes so that the full learn-and-consolidate lifecycle happens in one subagent call without polluting the primary context window.

## What you do

1. **Learn** — If the primary agent explored code and synthesized durable knowledge, store it now with `cog_mem_learn` (use `items` array for multiple), `cog_mem_associate` (use `items` array for multiple), `cog_mem_refactor`, `cog_mem_update`, or `cog_mem_deprecate` as appropriate. The primary agent will describe what it learned in the delegation prompt. Only store non-obvious, durable knowledge — skip trivial lookups.

2. **Consolidate** — Call `cog_mem_list_short_term` to check for pending short-term memories. Classify each entry, then batch:
   - `cog_mem_reinforce` with `engram_ids` array for all validated memories in one call
   - `cog_mem_flush` with `engram_ids` array for all wrong/redundant/irrelevant memories in one call
   - `cog_mem_verify` on synapses confirmed still accurate

3. **Return** — Report concisely what was learned and consolidated. Include engram IDs.

## Rules

- Never store passwords, API keys, tokens, secrets, PII
- Use strong predicates: `requires`, `implies`, `is_component_of`, `enables`, `contains`
- Avoid `related_to` and `similar_to`
- Every concept should have at least one association
- Terms should be 2-5 words, specific and qualified
- Definitions should explain WHY, not just WHAT
- If `cog_mem_list_short_term` returns nothing pending, skip step 2 — do not call validation tools unnecessarily
- Be concise — the primary agent needs a summary, not raw tool output
