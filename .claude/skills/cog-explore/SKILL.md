---
name: cog-explore
description: Batched workflow for Cog code intelligence: query batching rules, wildcard and synonym syntax, and follow-up discipline for cog_code_explore and cog_code_query. Load before the first code-intelligence call in a session.
compatibility: Requires the Cog MCP server (cog mcp) configured in this project
metadata:
  internal: "true"
  cog-version: "0.27.2"
---

# Batched Code Intelligence Workflow

Detailed procedure for `cog_code_explore` and `cog_code_query`. Load this before your first code-intelligence call in a session.

## Tools

- `cog_code_explore` — find symbols by name, return full definition bodies, file TOC, and optional architecture summaries. ALWAYS put all symbols into a single `queries` array — never split across multiple calls.
- `cog_code_query` — `find` (locate definitions), `refs` (find references), `symbols` (list file symbols), `imports` (module/file dependencies), `contains` (parent-child containment), `calls`/`callers` (approximate call graph), `overview` (symbol/file/repo architecture summary). ALWAYS use the `queries` array to combine multiple queries into one call.
- Include synonyms with `|`: `banner|header|splash`
- Wildcard symbol patterns: `*init*`, `get*`, `Handle?`

## Batching Rules

Both tools accept a `queries` array. Making sequential calls to the same tool when a single batched call would work is an error. Combine them.

- `cog_code_explore`: put ALL symbols into one `queries` array. Do not call it twice when both calls could be one.
- `cog_code_query`: put ALL queries into one `queries` array. Each entry specifies its own `mode`, `name`, `file`, `kind`, `direction`, `scope`. Example: symbols for 3 files = one call with 3 entries, not 3 calls.
- For repository-understanding tasks: one initial `cog_code_explore` with `include_architecture=true` and `overview_scope="repo"`, then at most one targeted follow-up.
- Before making follow-up calls, check whether the answer is already present in prior output.
- Prefer `cog_code_query` over raw file reads for architectural questions.
- Budget: 2-3 code-intelligence calls before responding.

## Follow-up discipline

`cog_code_explore` results include `file_symbols` (a table of contents for each file) and `references` (symbols called within each body). One call is usually sufficient — check those sections before issuing another query. Valid follow-ups are `refs` for call sites and one targeted `overview`/`imports`/`contains`/`calls`/`callers` query when a single concrete ambiguity remains.
