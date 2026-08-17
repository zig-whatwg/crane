---
name: cog-remember
description: Rules and quality guardrails for recording durable knowledge with Cog memory: IF-THEN recording triggers, concept and predicate quality, and array batching. Load before calling cog_mem_learn, cog_mem_associate, or other memory-writing tools.
compatibility: Requires the Cog MCP server (cog mcp) configured in this project
metadata:
  internal: "true"
  cog-version: "0.27.2"
---

# Recording Knowledge with Cog Memory

Detailed procedure for writing durable memory with `cog_mem_*` tools. Load this whenever you are about to record, associate, or maintain memories.

**All memory tools require arrays** — `items` for learn/associate, `queries` for recall, `engram_ids` for get/connections/reinforce/flush. Always pass an array, even for a single entry. Gather related operations into one batched call.

## IF-THEN rules

- IF you completed analysis that required reasoning across multiple symbols or files, THEN call `cog_mem_learn` with an `items` array immediately, before writing response text.
- IF A relates to B, THEN call `cog_mem_associate` with an `items` array using a strong predicate.
- IF you discovered a sequence A -> B -> C, THEN call `cog_mem_learn` with `chain_to` in the items entry.
- IF a concept connects to multiple others, THEN call `cog_mem_learn` with `associations` in the items entry.
- IF you changed code for a known concept, THEN call `cog_mem_refactor`.
- IF a feature was deleted, THEN call `cog_mem_deprecate`.
- IF a term or definition is wrong, THEN call `cog_mem_update`.

## Quality guardrails

- Store non-obvious, durable knowledge that would save future reasoning.
- Do not store generic repo summaries or facts that are obvious from a quick README or file read unless they capture durable workflow or architectural conventions.
- When learning implementation details, prefer storing why plus what so recall preserves the design reason, not just the surface behavior.
- When the user explains a design decision, treat it as durable architectural context instead of collapsing it into a generic summary.
- When a constraint or invariant is given, store it explicitly as a constraint, invariant, or workflow rule.
- When something changes or is deprecated, preserve the old-to-new relationship when the available tools can express it.

## Concept quality

What you store determines what agents can recall later:

- **term**: 2-5 words, specific and qualified. Bad: "Configuration". Good: "CLI Settings Loader".
- **definition**: 1-3 sentences explaining WHY, not just WHAT. Include function names, patterns, and technical terms — these drive keyword search during recall.

**Predicate choice** matters for recall quality. Prefer strong predicates: `requires`, `implies`, `is_component_of`, `enables`, `contains`. Avoid `related_to` and `similar_to` — these weaken graph traversal signal. Every concept should have at least one association; orphans are nearly invisible during recall.

New memories are short-term (24h decay) unless reinforced. Never store secrets, credentials, or PII.
