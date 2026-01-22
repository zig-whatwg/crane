# Agent Guidelines for WHATWG Specifications Monorepo in Zig

## Knowledge Management with Cog

You have access to Cog, a persistent memory system for storing and retrieving knowledge across sessions. Your API token is automatically linked to a specific brain, so no brain_id is needed in any tool calls.

**Cog persists across sessions and conversations.** Knowledge recorded today is available in future sessions. This is why recording learnings is valuable - future agents (including yourself in a new conversation) will benefit from past discoveries.

Cog implements biologically-inspired memory: concepts are stored as **engrams** and linked via **synapses**. When you recall knowledge, activation spreads through connected concepts—just like biological memory retrieval.

### Available Tools

| Tool | Purpose |
|------|---------|
| `cog_remember` | Store a new concept (term + definition) |
| `cog_recall` | Search for concepts with optional spreading activation (`expand: true`) |
| `cog_get` | Retrieve a specific engram by ID |
| `cog_associate` | Link two concepts with a relationship predicate |
| `cog_trace` | Find reasoning paths between two concepts |
| `cog_update` | Modify an existing engram's term or definition |
| `cog_unlink` | Remove a synapse between concepts |
| `cog_connections` | List all connections from/to an engram |
| `cog_bootstrap` | Get a codebase exploration prompt (empty brains only) |

---

### Visual Indicators for Cog Usage

**ALWAYS print visual indicators when using Cog tools** so the user knows memory operations are happening:

| Operation | Indicator |
|-----------|-----------|
| Querying | `⚙️ Querying Cog...` |
| Recording | `🧠 Recording to Cog...` |
| Linking | `🧠 Linking concepts...` |
| Updating | `🧠 Updating engram...` |
| Tracing | `⚙️ Tracing connections...` |
| Exploring | `⚙️ Exploring connections...` |
| Unlinking | `🧠 Removing link...` |

**Use `⚙️` for read operations (querying, tracing, exploring) and `🧠` for write operations (recording, linking, updating, unlinking).**

**Example usage in responses:**
```
⚙️ Querying Cog...

Based on prior knowledge, I found that...
```

```
🧠 Recording to Cog...
🧠 Linking concepts...
```

This transparency helps users understand when persistent memory is being accessed or modified.

---

### Starting Fresh: Codebase Exploration

If the brain is empty and you're exploring a new codebase, use `cog_bootstrap` to get a comprehensive exploration prompt:

```
cog_bootstrap({})
```

This returns a detailed system prompt guiding you through systematic codebase analysis and knowledge recording.

---

### Retrieving Knowledge

The brain recalls **constellations**, not isolated facts. When you need context:

#### With Spreading Activation (Recommended)

```
cog_recall({"query": "authentication", "expand": true})
```

Returns:
- **Direct matches**: Concepts matching your query
- **Connected context**: Related concepts reached via synapses (with activation levels)
- **Paths**: How concepts are connected (predicates showing the relationship)

Use `expand_depth` to control how far activation spreads (default: 2 hops):
```
cog_recall({"query": "error handling", "expand": true, "expand_depth": 3})
```

#### Quick Lookups (No Expansion)

```
cog_recall({"query": "specific function name"})
```

#### Deep Path Exploration

```
cog_trace({"from_id": "<concept_a>", "to_id": "<concept_b>"})
```

---

### When to Use Each Tool

| Tool | Use When |
|------|----------|
| `cog_recall` | Starting any task, searching for concepts, exploring a topic |
| `cog_get` | You have a specific engram ID and need its full definition |
| `cog_trace` | Understanding WHY/HOW two concepts connect (shows multi-hop paths) |
| `cog_connections` | Exploring what a concept links to before updating, or finding related concepts |
| `cog_associate` | Linking new or existing concepts with semantic relationships |
| `cog_update` | Correcting or clarifying an existing engram's definition |
| `cog_unlink` | Removing an incorrect synapse (NOT the engram itself) |

**Example - Using `cog_trace` to understand connections:**
```
cog_trace({"from_id": "<worker_concept_id>", "to_id": "<event_loop_concept_id>"})
```
Returns paths like: Worker → requires → V8 Isolate → is_component_of → Event Loop

**Example - Using `cog_connections` to explore neighbors:**
```
cog_connections({"engram_id": "<concept_id>", "direction": "both"})
```
Returns all incoming and outgoing links with their predicates and weights.

---

### ⚠️ CRITICAL: Always Query Cog First

**BEFORE starting ANY task - bug fix, feature, investigation, or research - you MUST query Cog first.**

This is non-negotiable. Cog may have:
- Prior knowledge about the exact problem you're facing
- Related gotchas or pitfalls discovered in previous sessions
- Architectural context that speeds up understanding
- Solutions to similar problems

**Even if Cog returns nothing or partial information, you MUST check first.** The query takes seconds; rediscovering knowledge takes hours.

```
cog_recall({"query": "Worker event loop blob URL", "expand": true})
```

**Do this BEFORE:**
- Reading code
- Running tests
- Starting to debug
- Writing implementation plans

**The query should include keywords related to:**
- The component/module you're working on (e.g., "Worker", "URL", "Streams")
- The type of problem (e.g., "crash", "memory leak", "timing")
- Technologies involved (e.g., "V8", "isolate", "event loop")

**If the first query returns nothing useful:**
1. Try broader keywords (e.g., "Worker" instead of "DedicatedWorker")
2. Try related terms (e.g., "message passing" instead of "postMessage")
3. Try technology keywords (e.g., "V8 isolate" instead of "JavaScript context")

Cog uses hybrid search (70% semantic + 30% keyword), so both exact terms and conceptually similar queries work.

### ⚠️ CRITICAL: Subagents Must Also Query Cog First

**When spawning subagents via the Task tool, you MUST include explicit instructions for the subagent to query Cog first.**

Subagents do NOT automatically inherit CLAUDE.md instructions. They only receive the prompt you provide. Therefore, every Task prompt for research, exploration, or investigation MUST begin with:

```
⚙️ Query Cog first for any prior knowledge about [relevant keywords].

Then [rest of the task...]

If you discover non-trivial learnings, record them:
🧠 Recording to Cog...
```

**Example - CORRECT Task prompt:**
```
⚙️ Query Cog first for any prior knowledge about V8 ShadowRealm GetWrappedValue or value boundary crossing.

Then search in /Users/bcardarella/projects/chromium for V8's GetWrappedValue implementation...

If you discover important implementation details or gotchas, use cog_remember to record them.
Use 🧠 emoji prefix when recording (e.g., "🧠 Recording to Cog...").
```

**Example - WRONG Task prompt (missing Cog instruction):**
```
Search in /Users/bcardarella/projects/chromium for V8's GetWrappedValue implementation...
```

**Why this matters:**
- Subagents may duplicate research that's already been done
- Prior sessions may have already solved the exact problem
- Knowledge in Cog can shortcut hours of investigation
- Subagents should contribute TO Cog, not just consume resources

**Visual indicators for subagents:**
- `⚙️` for read operations (querying Cog)
- `🧠` for write operations (recording learnings, linking concepts)

**Checklist before launching any Task:**
1. Did I query Cog myself first? (before even deciding to spawn a subagent)
2. Does my Task prompt include "⚙️ Query Cog first for..." as the FIRST instruction?
3. Does my Task prompt include relevant keywords for the Cog query?
4. Does my Task prompt instruct subagent to record learnings with "🧠" prefix?

### Using Query Results

1. **Use the full context**, not just direct matches:
   - `requires` links show prerequisites you might be missing
   - `contrasts_with` links show alternative approaches
   - `implies` links show consequences to consider
   - `temporally_related` links show concepts learned in the same session

2. **If knowledge proves incorrect**, determine the severity:

   | Update (minor) | Disconnect + Create New (major) |
   |----------------|--------------------------------|
   | API behavior clarification | Feature completely refactored |
   | Version/syntax changes | Module/file deleted or renamed |
   | Missing edge case | Architecture fundamentally changed |

   **Minor correction:**
   ```
   cog_update({"engram_id": "<id>", "definition": "Corrected explanation..."})
   ```

   **Major change:**
   ```
   cog_connections({"engram_id": "<stale_id>"})
   cog_unlink({"synapse_id": "<each_synapse_id>"})
   cog_remember({"term": "Updated concept", "definition": "Current accurate explanation..."})
   ```

---

### How Cog Handles Conflicts

Cog uses **idempotent deduplication**, not explicit conflict resolution:

- **Duplicate concepts**: If you try to remember something ≥90% similar to an existing engram, Cog activates the existing one instead of creating a duplicate
- **Repeated associations**: Calling `cog_associate` on existing links strengthens them (LTP) rather than failing
- **Contradictory information**: Both facts coexist - create explicit `contradicts` links if needed

**When Cog conflicts with current code or user statements:**
1. **Trust the code/user over Cog** - code is the source of truth
2. **Update the engram** with `cog_update` to correct it
3. **If fundamentally wrong**, unlink the engram's connections and create a new one

---

### Recording Knowledge

When you learn something new that is:
1. **Verified** - You've confirmed it works (ran tests, saw output, validated behavior)
2. **Non-trivial** - Not obvious or well-documented elsewhere
3. **Reusable** - Could be helpful in future sessions

Store it in Cog:

1. **Search first** to avoid duplicates:
   ```
   cog_recall({"query": "Phoenix LiveView navigation"})
   ```

2. **Create the engram**:
   ```
   cog_remember({
     "term": "Phoenix LiveView push_navigate behavior",
     "definition": "push_navigate/2 triggers a full LiveView mount cycle, not a patch. Use push_patch/2 for same-LiveView navigation to preserve state."
   })
   ```

3. **Query for existing related concepts** - Don't just link new engrams to each other; find existing concepts they connect to:
   ```
   cog_recall({"query": "V8 event loop isolate", "expand": true})
   ```

4. **Link to BOTH new and existing concepts** - New knowledge should integrate into the existing graph:
   ```
   // Link new engrams to each other
   cog_associate({
     "source_id": "<new_engram_id>",
     "target_id": "<other_new_engram_id>",
     "predicate": "related_to"
   })

   // Link new engrams to existing related concepts
   cog_associate({
     "source_id": "<new_engram_id>",
     "target_id": "<existing_related_id>",
     "predicate": "is_component_of"  // or appropriate predicate
   })
   ```

### Writing Good Engrams

**Terms (2-5 words):**
- ✅ "V8 HandleScope Corruption Pattern"
- ✅ "Blob URL Fetch Timing"
- ✅ "Event Loop Task Draining"
- ❌ "Worker.zig" (just a filename)
- ❌ "Error handling" (too vague)
- ❌ "The bug fix" (not searchable)

**Definitions (1-3 sentences) should answer:**
1. **What is this?** - The core concept
2. **Why does it matter?** - Consequences of not knowing this
3. **Context** - Where it applies (optional file paths, conditions)

**Example of a good engram:**
```
Term: "V8 HandleScope corruption from nested isolate entry"
Definition: "Entering a worker's V8 isolate synchronously from within a V8
callback corrupts the calling isolate's HandleScope state, causing 'Cannot
create a handle without a HandleScope' crashes. Worker isolate entry must
be deferred via queueTask or setTimeout to run after V8 restores its state."
```

**Why this matters:** Isolated engrams won't surface in future queries. The value of Cog comes from spreading activation through connected concepts. New learnings should connect to the existing knowledge graph so they're discoverable when querying related topics.

**Note:** Concepts created close in time are automatically linked with `temporally_related` synapses, but these weak links are not sufficient - explicit semantic associations are needed.

---

### Relationship Predicates

When linking concepts, use the most specific predicate:

| Predicate | Meaning |
|-----------|---------|
| `requires` | A is prerequisite for B |
| `implies` | If A then B |
| `contradicts` | A and B are mutually exclusive |
| `leads_to` | A naturally flows to B |
| `is_component_of` | A is part of B |
| `contains` | A includes B |
| `example_of` | A demonstrates pattern B |
| `generalizes` | A is broader version of B |
| `similar_to` | A and B are related concepts |
| `contrasts_with` | A and B differ importantly |
| `supersedes` | A replaces B |
| `derived_from` | A came from B |
| `precedes` | A comes before B |
| `related_to` | General link (use sparingly) |
| `temporally_related` | A and B were created close in time (auto-generated) |

---

### What to Remember

**Good candidates:**
- Bug fixes and their root causes
- Non-obvious API behaviors discovered through experimentation
- Project-specific patterns or conventions
- Workarounds for framework/library quirks
- Performance insights from profiling
- Architecture decisions and their rationale
- Common gotchas and pitfalls

**Do NOT remember:**
- Standard documentation that's easily searchable
- Temporary debugging steps
- User preferences (use CLAUDE.md for those)
- Secrets or credentials
- Trivial or obvious information

---

### Limitations

- **No engram deletion**: There is no MCP tool to delete engrams entirely. If an engram is wrong:
  1. Use `cog_update` to correct the definition
  2. Use `cog_unlink` to remove incorrect synapses
  3. For obsolete concepts, update the definition to note "DEPRECATED: [reason]"

- **No multi-query**: Each `cog_recall` is independent. Chain queries manually if needed.

- **Synapse uniqueness**: Only one synapse can exist between two engrams (same direction). Calling `cog_associate` again strengthens the existing link rather than creating a duplicate.

---

### How Spreading Activation Works

When you query with `expand: true`:

1. **Seeds**: Direct matches found (e.g., "Session Auth Pattern") with similarity scores
2. **Spread**: Activation flows through synapses to connected concepts
3. **Decay**: Activation diminishes with each hop (0.7x per hop by default)
4. **Threshold**: Spreading stops when activation falls below 0.2
5. **Strengthen**: All activated concepts become slightly more accessible for future recall

This mirrors biological memory:
- Recalling one memory activates related memories automatically
- Frequently co-accessed memories strengthen their connections
- The more a path is traversed, the stronger it becomes

## ⚠️ CRITICAL: Ask Clarifying Questions When Unclear

**ALWAYS ask clarifying questions when requirements are ambiguous or unclear.**

### Question-Asking Protocol

When you receive a request that is:
- Ambiguous or has multiple interpretations
- Missing key details needed for implementation
- Unclear about expected behavior or scope
- Could be understood in different ways

**YOU MUST**:
1. ✅ **Ask ONE clarifying question at a time**
2. ✅ **Wait for the answer before proceeding**
3. ✅ **Continue asking questions until you have complete understanding**
4. ✅ **Never make assumptions when you can ask**

### Examples of When to Ask

❓ **Ambiguous request**: "Implement URL parsing"
- **Ask**: "Should this implement the basic URL parser, the URL parser with base, or just host parsing?"

❓ **Missing details**: "Add encoding support"
- **Ask**: "Which encoding should be supported? Just UTF-8, or should this include legacy encodings like ISO-8859-1?"

❓ **Unclear scope**: "Optimize parser performance"
- **Ask**: "Which part should be prioritized? Character validation, state machine transitions, or memory allocation?"

❓ **Multiple interpretations**: "Handle parsing errors"
- **Ask**: "Should this throw validation errors, collect them for reporting, or fail silently according to the spec?"

### What NOT to Do

❌ **Don't make assumptions and implement something that might be wrong**
❌ **Don't ask multiple questions in one message** (ask one, wait for answer, then ask next)
❌ **Don't proceed with unclear requirements** hoping you guessed correctly
❌ **Don't over-explain options** in the question (keep questions concise)

### Good Question Pattern

```
"I want to make sure I understand correctly: [restate what you think they mean].

Is that correct, or did you mean [alternative interpretation]?"
```

**Remember**: It's better to ask and get it right than to implement the wrong thing quickly.

---

## ⚠️ CRITICAL: No Mid-Task Summaries

**NEVER provide summaries or progress reports in the middle of active work.**

### Summary Rules

**When to Provide Summaries**:
- ✅ **ONLY at the end of completed work** - After all tasks are done and committed
- ✅ **When explicitly asked** - User requests "What did we do?" or similar
- ✅ **After oneshot completion** - Final summary after entire epic is complete

**When NOT to Provide Summaries**:
- ❌ **During active work** - While implementing features, fixing bugs, or writing code
- ❌ **Between logical steps** - After completing one part of a multi-part task
- ❌ **After individual commits** - Just commit and continue to the next step
- ❌ **To update on progress** - Work silently, report only when done

### Correct Behavior

```
User: "Implement feature X"
Agent: [Works on feature X implementation]
Agent: [Commits code]
Agent: [Continues to next logical step]
Agent: [Commits more code]
Agent: [Completes all work]
Agent: "✅ Feature X is complete. [Brief completion note]"
```

### Incorrect Behavior

```
User: "Implement feature X"
Agent: [Works on part 1]
Agent: "I've completed part 1. Here's what I did: [long summary]" ❌ WRONG
Agent: [Works on part 2]
Agent: "Now I've finished part 2. Summary so far: [long summary]" ❌ WRONG
```

### Why This Matters

- **Efficiency**: Summaries break flow and waste time
- **Focus**: Stay focused on completing the work, not reporting on it
- **Clarity**: Final summaries are more valuable than incremental updates
- **User experience**: Users want completed work, not progress reports

**WORK FIRST, SUMMARIZE LAST. If you're not done, keep working.**

---

## ⚠️ CRITICAL: Spec-Compliant Implementation

**THIS IS A WHATWG SPECIFICATIONS MONOREPO** providing Zig implementations of multiple WHATWG standards for web platform compatibility.

### What This Monorepo IS

This project implements multiple WHATWG specifications in idiomatic Zig:

**Currently Implemented**:
- **URL** (`src/url/`) - URL parsing, serialization, and manipulation
- **Encoding** (`src/encoding/`) - Text encoding and decoding (UTF-8, legacy encodings)
- **Console** (`src/console/`) - Console logging and debugging APIs
- **MIME Sniff** (`src/mimesniff/`) - MIME type detection and sniffing
- **WebIDL** (`src/webidl/`) - WebIDL type system and conversions
- **Infra** (`src/infra/`) - Common infrastructure primitives (lists, strings, bytes)
- **Streams** (`src/streams/`) - Streaming data APIs (ReadableStream, WritableStream)

**Available Specs** (in `specs/`): URL, Encoding, Console, Fetch, DOM, Streams, WebIDL, Infra, MIME Sniff, and many more

**IDL Reference Files** (in `idl/`): Symlink to `/Users/bcardarella/projects/webref/ed/idl/` containing all official WHATWG WebIDL definitions used as the source for code generation.

### Context Awareness

**When working on a spec, the system detects context from:**
- File paths (e.g., `src/url/parser.zig` → URL Standard)
- Import statements (e.g., `@import("encoding")` → Encoding Standard)
- Current working directory

**The skills adapt based on detected context** to provide spec-specific guidance.

### Test Guidelines

- Use realistic examples from the target spec
- Test edge cases defined in the specification
- Focus on spec compliance: every operation must match spec algorithms
- Test cross-spec interactions (e.g., URL using Infra primitives)

**Example Test (URL)**:
```zig
test "URL - basic parsing" {
    const allocator = std.testing.allocator;
    
    const url = try URL.parse(allocator, "https://example.com:8080/path?query#fragment");
    defer url.deinit();
    
    try std.testing.expectEqualStrings("https", url.scheme);
    try std.testing.expectEqualStrings("example.com", url.host.?.domain);
    try std.testing.expectEqual(@as(?u16, 8080), url.port);
}

test "Encoding - UTF-8 decode" {
    const allocator = std.testing.allocator;
    
    const input: []const u8 = &[_]u8{ 0xE2, 0x9C, 0x93 }; // ✓
    const decoded = try decodeUtf8(allocator, input);
    defer allocator.free(decoded);
    
    try std.testing.expectEqualStrings("✓", decoded);
}
```

---

## Dynamic Skill Loading System

This project uses a **dynamic skill loading system** where the LLM should:
1. **Analyze the task** to determine which skills are required
2. **Load only the necessary skills** by reading their SKILL.md files
3. **Apply the skill knowledge** during task execution
4. **Unload skills** from working memory when no longer needed

### Available Skills

| Skill | Load When | Description |
|-------|-----------|-------------|
| **commit_workflow** | Committing code, managing git history | Incremental commit strategy - commit after each feature completion |
| **communication_protocol** | ALWAYS (every interaction) | Ask clarifying questions when requirements are ambiguous |
| **temporary_files** | ALWAYS (every interaction) | All AI-generated temporary files go to `tmp/` directory |
| **oneshot** | User explicitly requests "oneshot [task]" | Complete uninterrupted execution of entire task/epic with final summary only |
| **pre_commit_checks** | Before committing code | Automated format/build/test checks before every commit |
| **zig** | Writing/refactoring Zig code | Universal Zig best practices, memory management, testing, documentation |
| **cpp** | Writing/refactoring C++ code, V8 FFI wrappers | Modern C++ (C++17/C++20), RAII, V8 API patterns, FFI boundaries |
| **monorepo_navigation** | Finding dependencies across specs | Navigate monorepo structure, locate spec implementations |
| **dependency_mocking** | Creating temporary mocks for unimplemented specs | Temporary mocks with clear markers for missing dependencies |
| **webidl_codegen** | Working with WebIDL code generation | WebIDL code generation system, interface/namespace/mixin definitions |

### Skill Loading Protocol

**Before starting any task:**

1. **Identify required skills** based on task type:
   - User says "oneshot [task]" → Load `oneshot` skill (takes over execution)
   - Zig code changes → Load `zig` skill
   - C++ code changes (V8 wrappers) → Load `cpp` skill
   - Git operations → Load `commit_workflow` skill
   - Ambiguous requirements → `communication_protocol` (always active)
   - Temporary files → `temporary_files` (always active)
   - Pre-commit → Load `pre_commit_checks` skill
   - Finding dependencies → Load `monorepo_navigation` skill
   - Mocking unimplemented specs → Load `dependency_mocking` skill
   - WebIDL codegen → Load `webidl_codegen` skill

2. **Load skills** by reading the appropriate SKILL.md file:
   ```
   Read: skills/<skill_name>/SKILL.md
   ```
   
   **IMPORTANT**: When loading a skill, the LLM MUST announce it in the chat response:
   ```
   🔧 Loading skill: <skill_name>
   ```

3. **Apply skill knowledge** during task execution

4. **Unload skills** when done:
   - Keep only relevant skills in working memory
   - Unload skills that are no longer needed for current task
   - Communication protocol and temporary_files are ALWAYS active (never unload)
   
   **IMPORTANT**: When unloading a skill, the LLM MUST announce it in the chat response:
   ```
   ✓ Unloading skill: <skill_name>
   ```

### Skill Usage Decision Tree

```
Task received
    ↓
Analyze task type
    ↓
┌──────────────────────────────────────┐
│ Did user say "oneshot [task]"?       │ → YES → Load: oneshot (takes over execution)
└──────────────────────────────────────┘
    ↓ NO
┌──────────────────────────────┐
│ Is this Zig code?            │ → YES → Load: zig
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Is this C++ code (V8 FFI)?  │ → YES → Load: cpp
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Is this a git commit?        │ → YES → Load: commit_workflow, pre_commit_checks
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Need to find dependencies?   │ → YES → Load: monorepo_navigation
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Need to mock dependencies?   │ → YES → Load: dependency_mocking
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Working with WebIDL codegen? │ → YES → Load: webidl_codegen
└──────────────────────────────┘
    ↓ ALSO CHECK
┌──────────────────────────────┐
│ Are requirements unclear?    │ → YES → Use: communication_protocol (already loaded)
└──────────────────────────────┘
    ↓
Execute task with loaded skills
    ↓
Task complete
    ↓
Unload skills no longer needed
```

### Skill Combinations

Common task scenarios and their skill requirements:

| Task Scenario | Skills to Load |
|---------------|----------------|
| **Oneshot execution** | `oneshot` (then loads others as needed: `zig`, `cpp`, `commit_workflow`, etc.) |
| **Implement new WHATWG spec feature** | `zig`, `monorepo_navigation` |
| **Implement V8 FFI wrapper** | `cpp` |
| **Add V8 TypedArray API** | `cpp`, `zig` (for FFI bindings) |
| **Fix bug in Zig code** | `zig` |
| **Fix bug in C++ wrapper** | `cpp` |
| **Commit code** | `commit_workflow`, `pre_commit_checks` |
| **Clarify requirements** | `communication_protocol` (always active) |
| **Write Zig tests** | `zig` |
| **Refactor Zig code** | `zig`, `commit_workflow` |
| **Refactor C++ code** | `cpp`, `commit_workflow` |
| **Mock unimplemented dependency** | `dependency_mocking`, `zig` |
| **Work with WebIDL codegen** | `webidl_codegen`, `zig` |
| **Find cross-spec dependencies** | `monorepo_navigation` |

### Example Workflow

**Scenario**: User asks to "implement a new URL parser function"

**LLM Response:**

```
I'll implement a new URL parser function for you.

🔧 Loading skill: commit_workflow
🔧 Loading skill: zig

First, let me create an issue to track this work...

Now I'll implement the parser function following Zig best practices...
[Implements code using zig skill]

Writing comprehensive tests...
[Writes tests using zig skill]

Updating issue progress...

The implementation is complete. Now let me commit the changes.

✓ Unloading skill: zig
🔧 Loading skill: commit_workflow
🔧 Loading skill: pre_commit_checks

Running pre-commit checks...
[Executes format, build, test]

Committing changes...
[Creates commit using commit_workflow]

✓ Unloading skill: commit_workflow
✓ Unloading skill: pre_commit_checks

Closing the issue...


✅ URL parser function implemented, tested, and committed!
```

### Example Workflow: Oneshot Execution

**Scenario**: User asks to "oneshot bd-42" (a feature to implement URL host parser)

**LLM Response:**

```
🔧 Loading skill: oneshot
🔧 Loading skill: zig
🔧 Loading skill: monorepo_navigation

# Oneshot Execution Summary: Implement URL Host Parser

## Completed Work

✅ **Core Parser**
- Implemented host parsing state machine
- Added IPv4, IPv6, and domain parsing
- Committed in: "feat(url): implement host parser state machine"

✅ **Infra Integration**
- Integrated Infra primitives for string handling
- Committed in: "feat(url): integrate Infra primitives in host parser"

✅ **Error Handling**
- Added ParseError with spec-compliant messages
- Committed in: "feat(url): add host parse error handling"

✅ **Tests**
- Added 64 comprehensive test cases covering all host types
- Committed in: "test(url): add comprehensive host parser tests"

✅ **Documentation**
- Added inline docs with WHATWG URL spec references
- Committed in: "docs(url): document host parser with spec citations"

## Commits Made

- abc1234: feat(url): implement host parser state machine
- def5678: feat(url): integrate Infra primitives in host parser
- ghi9012: feat(url): add host parse error handling
- jkl3456: test(url): add comprehensive host parser tests
- mno7890: docs(url): document host parser with spec citations

## Incomplete Work

None - all planned work completed.

## Statistics

- **Total features completed**: 5
- **Total commits**: 5
- **Tests added**: 64
- **Files modified**: 4
- **Lines of code**: +1247/-45

## Issue Status

- **Issue**: bd-42
- **Final status**: closed
- **Completion**: 100%

✓ Unloading skill: oneshot
✓ Unloading skill: zig
✓ Unloading skill: monorepo_navigation

✅ URL host parser implemented, tested, and committed!
```

### Skill Loading Commands

**To load a skill:**
```
Read the SKILL.md file for that skill to understand the complete workflow and patterns.
```

**To reference quick usage:**
```
Read the USAGE.md file for quick reference on when to use the skill.
```

**To unload a skill:**
```
Remove skill knowledge from working memory when no longer relevant to current task.
```

### Important Notes

- **Communication protocol and temporary_files** are ALWAYS active - never need loading/unloading (no announcement needed)
- **Load skills lazily** - only when needed
- **Unload proactively** - free up working memory
- **Combine skills** when tasks require multiple areas of expertise
- **Reload if needed** - Can reload a skill if task requirements change
- **Always announce** - Use `🔧 Loading skill: <name>` and `✓ Unloading skill: <name>` in chat responses
- **Transparency** - Skill loading/unloading announcements help users understand the LLM's decision-making process

---

## WHATWG Specifications

**Specifications are organized in the `specs/` directory:**

**WHATWG Spec Files** (`specs/whatwg/`):
- All WHATWG specification markdown files organized by spec
- Contains algorithms, state machines, and implementation details
- Examples: URL, Encoding, Streams, Infra, WebIDL, Console, MIME Sniff, DOM, Fetch

**IDL Files** (`specs/idl/`):
- Symlink to `/Users/bcardarella/projects/webref/ed/idl/`
- Contains all official WHATWG WebIDL interface definitions
- Source files for code generation (333 IDL files)

**Supplementary IDL** (`specs/supplementary/`):
- Additional type definitions for testing
- Examples: `PostMessageOptions.idl`, `XRFeatureInit.idl`

**Algorithm Files** (`specs/algorithms/`):
- JSON files containing algorithm definitions
- Used for processing and analysis

**Always load complete spec sections** from these files into context when implementing features. Never rely on grep fragments - every algorithm has context and edge cases that matter.

### Cross-Spec Dependencies

WHATWG specifications frequently reference each other:

**Common Dependencies**:
- **Infra** (`src/infra/`) - Primitives used by nearly all specs (strings, bytes, lists, ordered maps)
- **WebIDL** (`src/webidl/`) - Type system and conversions used by all specs with Web APIs

**Spec-Specific Dependencies**:
- **URL** depends on: Infra, WebIDL
- **Encoding** depends on: Infra, WebIDL
- **Streams** depends on: Infra, WebIDL
- **Fetch** depends on: URL, Streams, Infra, WebIDL, MIME Sniff
- **Console** depends on: WebIDL

**Finding Dependencies**: Use the `monorepo_navigation` skill to locate implementations in `src/` or create temporary mocks for unimplemented specs.

## Memory Management

All WHATWG spec implementations use standard Zig allocation patterns - allocate for heap types, deinit when done.

### Standard Allocation Pattern

```zig
// URL (allocates for components)
const url = try URL.parse(allocator, "https://example.com/path");
defer url.deinit();

// Access components (no additional allocation)
const scheme = url.scheme; // "https"
const host = url.host; // Host struct

// Serialization (allocates new string)
const serialized = try url.serialize(allocator);
defer allocator.free(serialized);

// Encoding (allocates for decoded output)
const decoded = try decoder.decode(allocator, input);
defer allocator.free(decoded);

// Streams (allocates for stream state and queue)
var stream = try ReadableStream.init(allocator, .{
    .pull = myPullFn,
});
defer stream.deinit();
```

### Memory Safety

- **Always use `defer`** for cleanup immediately after allocation
- **Always test with `std.testing.allocator`** to detect leaks
- **No global state** - everything takes an allocator parameter
- **Allocator threading** - pass allocator through call chain, don't store globally
- **Error cleanup** - use `errdefer` to clean up on error paths

### Pre-Commit Quality Checks

Before every commit, these checks MUST pass:

1. **Code formatting** - `zig fmt` (automatic style enforcement)
2. **Build success** - `zig build` (no compilation errors)
3. **Test success** - `zig build test` (all tests pass)

**Automation Level**: **Recommended but Optional**

- **Recommended**: Install pre-commit hooks to automate checks (see `skills/pre_commit_checks/SKILL.md`)
- **Acceptable**: Run checks manually before each commit
- **Not Acceptable**: Commit without running checks

**Installing Pre-Commit Hooks** (Optional but Recommended):
```bash
# Create .git/hooks/pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
zig fmt --check src/ || exit 1
zig build || exit 1
zig build test || exit 1
EOF
chmod +x .git/hooks/pre-commit
```

See `skills/pre_commit_checks/SKILL.md` for complete setup guide.


### Managing AI-Generated Documents

**DEFAULT: ALL AI-generated documents go to `tmp/` unless user explicitly requests otherwise.**

AI assistants create documents during development. By default, ALL of these go to `tmp/`:

#### Default Location: `tmp/` (Required for ALL AI-generated content)
Store in `tmp/` directory by default:
- Session summaries, completion reports → `tmp/summaries/`
- Investigation notes, analysis → `tmp/analysis/`
- Implementation plans, design docs → `tmp/plans/`
- Debug output, test results → `tmp/debug/`
- Scratch scripts and utilities → `tmp/scratch/`

**Characteristics:**
- Created during development work
- Useful for current session/task
- Must be gitignored
- Can be deleted when no longer needed

**Decision Tree:**
```
Did user explicitly request a different location?
  ├─ NO  → tmp/ (DEFAULT for ALL AI-generated content)
  └─ YES → Use the location user requested (root, history/, etc.)
```

### Important Rules

- ✅ Store AI-generated docs in `tmp/` by default (unless explicitly requested otherwise)
- ❌ Do NOT clutter repo root with temporary documents

---

## Golden Rules

These apply to ALL work on this project:

### 0. **Query Cog First** ⭐⭐⭐
**BEFORE doing ANYTHING else, query Cog for prior knowledge.** This is the FIRST action for ANY task.

```
cog_recall({"query": "relevant keywords here", "expand": true})
```

Cog may have solutions, gotchas, or context from previous sessions. Even if it returns nothing, you MUST check. Rediscovering knowledge wastes hours; querying takes seconds.

**This rule takes precedence over all other rules.** Don't read code, don't write tests, don't start debugging until you've queried Cog.

### 1. **Ask When Unclear** ⭐
When requirements are ambiguous or unclear, **ASK CLARIFYING QUESTIONS** before proceeding. One question at a time. Wait for answer. Never assume.

### 2. **Complete Spec Understanding**
Load the complete WHATWG specification from `specs/` into context. Read the full algorithm sections with proper context. Never rely on grep fragments - every algorithm has context and edge cases.

### 3. **Algorithm Precision**
WHATWG specs define web platform behavior. Implement EXACTLY as specified, step by step. Even small deviations can break compatibility with browsers and cause unexpected behavior.

### 4. **Memory Safety**
Zero leaks, proper cleanup with defer, test with `std.testing.allocator`. No exceptions. Every allocation must have a corresponding deinit or free.

### 5. **Test Thoroughly**
Write comprehensive tests for all implementations. Test-driven development (TDD) is encouraged but not mandatory. All algorithm steps, edge cases, and error conditions must have test coverage before committing.

### 6. **Browser Compatibility**
Implementations must match browser behavior. Test against edge cases and boundary conditions. When in doubt, check how browser implementations (Chrome, Firefox, Safari) handle it.

### 7. **Performance Matters** (but spec compliance comes first)
WHATWG specs underpin all web platform functionality. Optimize for performance where possible. But never sacrifice correctness for speed.

### 8. **Commit Frequently** ⭐⭐⭐
**COMMIT AFTER EVERY LOGICAL UNIT OF WORK.** This is non-negotiable. Do not accumulate changes. Commit when you:
- Complete a feature or fix
- Finish refactoring a module
- Add tests that pass
- Update documentation
- Make any working, tested change

**Use descriptive commit messages** following the project's conventional commit style. See "Workflow" sections below for commit procedures.

### 9. **Handle Dependencies Correctly** ⭐
When a spec depends on another spec, check `src/` for implementation. If not implemented, create a temporary mock with clear markers. Never skip dependency handling.

### 10. **All Temporary Files Go to tmp/** ⭐
**DEFAULT: ALL** AI-generated summaries, analyses, plans, and temporary documentation MUST go into `tmp/` directory by default. Never clutter project root. Only place files elsewhere when user explicitly requests it. See `skills/temporary_files/SKILL.md` for complete policy.

### 11. **NEVER Modify Generated Files Directly** ⭐⭐⭐
**Files in `src/webidl/` subdirectories (interfaces/, typedefs/, dictionaries/, callbacks/) are code-generated outputs. NEVER make direct changes to them unless explicitly directed by the user.**

**General Rule:**
- Generated files in `src/webidl/interfaces/`, `src/webidl/typedefs/`, etc. are automatically generated by the codegen system
- Changes MUST be made to the codegen source files in `src/webidl/codegen/` or the source IDL files
- After updating codegen, regenerate ALL files with: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`

**Exception for Bug Fix Experimentation ONLY:**
1. ✅ You MAY temporarily edit a generated file to quickly test/experiment with a bug fix
2. ⚠️ Once the fix is working, you MUST:
   - Update the codegen source files to produce that same fix
   - Regenerate ALL generated files: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
   - The codegen will overwrite your temporary edits (this validates the codegen works correctly)
   - Rerun all tests to verify the codegen changes worked properly
3. ❌ NEVER commit manual/temporary edits to generated files
4. ❌ NEVER leave generated files in a manually-edited state

**Committing Generated Files:**
- ✅ **DO commit generated files** when they are properly regenerated by codegen
- ❌ **DO NOT commit manual edits** to generated files
- Generated files in `src/webidl/` subdirectories should be committed to version control
- Generated files change when codegen logic changes or IDL files are updated

**Codegen Command:**
```bash
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
```

**Why This Matters:**
- Generated files are overwritten on every codegen run
- Manual edits to generated files will be lost
- The codegen is the source of truth for all generated code
- All improvements must flow through the codegen system

**Workflow:**
1. Identify bug in generated file
2. Create temporary fix in generated file to test (OPTIONAL - only for experimentation)
3. Update codegen source files with the fix
4. Run: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
5. Verify tests pass
6. Commit codegen changes AND regenerated files together

### 12. **Implementation Files (impls/) Workflow** ⭐⭐⭐

**Implementation files in `src/webidl/impls/` contain CUSTOM CODE and are NOT overwritten by codegen.**

**Directory Structure:**
- `src/webidl/impls/` - **Canonical implementations** (committed, compiled, contains custom code)
- `src/webidl/impls_tmp/` - **Generated stubs** (gitignored, NOT compiled, reference only)

**How It Works:**
1. Codegen ALWAYS generates impl stubs to `impls_tmp/` (never to `impls/`)
2. `impls_tmp/` is gitignored and NOT part of the build
3. `impls/` contains the real implementations with custom logic
4. Developers manually migrate stubs from `impls_tmp/` to `impls/`

**Workflow for NEW Interfaces:**
1. Run codegen: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
2. Find the new stub in `src/webidl/impls_tmp/NewInterface.zig`
3. Copy the stub to `src/webidl/impls/NewInterface.zig`
4. Implement the actual logic in the copied file
5. Commit the implementation in `impls/`

**Workflow for EXISTING Interfaces (when signatures change):**
1. Run codegen to regenerate stubs in `impls_tmp/`
2. Diff `impls_tmp/ExistingInterface.zig` against `impls/ExistingInterface.zig`
3. Manually merge new/changed signatures into `impls/` while preserving custom code
4. Test and commit

**Critical Rules:**
- ✅ **DO** copy stubs from `impls_tmp/` to `impls/` for new interfaces
- ✅ **DO** manually merge signature changes while preserving implementations
- ✅ **DO** commit files in `impls/` (they contain custom code)
- ❌ **NEVER** compile or import from `impls_tmp/` - it's reference only
- ❌ **NEVER** commit files in `impls_tmp/` - it's gitignored
- ❌ **NEVER** expect codegen to preserve custom code in `impls/`

**Why This Design:**
- Protects custom implementation code from being overwritten
- Provides updated stubs for reference when IDL changes
- Allows diffing to see what changed in interface signatures
- Keeps generated stubs separate from canonical implementations

### 13. **NEVER Call Impls Directly from External Code** ⭐⭐⭐

**External code MUST call through interfaces, NEVER directly call impls.**

**Architecture:**
- **Interfaces** (`src/webidl/interfaces/`) - The public API that external code uses
- **Impls** (`src/webidl/impls/`) - Internal implementations that manage state and logic
- Only interfaces can call impls (via delegation)
- Impls can call other impls when implementing algorithms

**Correct Pattern:**
```zig
// External code (e.g., src/html/script_execution.zig)
const interfaces = @import("interfaces");
const HTMLScriptElement = interfaces.HTMLScriptElement;

// ✅ CORRECT: Call through interface
HTMLScriptElement.prepareTheScriptElement(element);
```

**Wrong Pattern:**
```zig
// External code
const impls = @import("impls");
const HTMLScriptElementImpl = impls.HTMLScriptElement;

// ❌ WRONG: Direct impl call from external code
HTMLScriptElementImpl.hasAlreadyStarted(element);
```

**When You Need Internal State Access:**
If external code needs to call methods that access internal state (like `hasAlreadyStarted`):
1. Move the algorithm logic INTO the impl
2. Add a delegate method in the interface
3. External code calls the interface method

**Example Refactoring:**
```zig
// 1. Impl contains the algorithm (src/webidl/impls/HTMLScriptElement.zig)
pub fn prepareTheScriptElement(instance: *Instance) !void {
    if (hasAlreadyStarted(instance)) return;  // Can call internal methods
    setAlreadyStarted(instance, true);
    // ... rest of algorithm
}

// 2. Interface delegates (src/webidl/interfaces/HTMLScriptElement.zig)
pub fn prepareTheScriptElement(instance: *Instance) !void {
    return HTMLScriptElementImpl.prepareTheScriptElement(instance);
}

// 3. External code uses interface only
const HTMLScriptElement = @import("interfaces").HTMLScriptElement;
HTMLScriptElement.prepareTheScriptElement(element);
```

**Why This Matters:**
- Interfaces provide a stable public API
- Impls can change internal implementation without breaking external code
- Proper encapsulation of internal state
- Interfaces can add cross-cutting concerns (CEReactions, logging, etc.)

**Files That Violate This Rule (MUST be refactored):**
- `src/html/script_execution.zig` - Uses HTMLScriptElementImpl, DocumentImpl, NodeImpl, ElementImpl, TextImpl
- `src/streams/internal/from_iterable_algorithm.zig` - Uses ReadableStreamDefaultControllerImpl
- `src/streams/internal/readable_stream_async_iterator.zig` - Uses impls.ReadableStreamDefaultReader
- `src/streams/internal/algorithms/reader_ops.zig` - Uses multiple impls directly

See epic `whatwg-jwgc` for the refactoring plan.

### 14. **Impls MUST Call Interfaces, NOT Other Impls** ⭐⭐⭐

**When an impl needs to use another type, it MUST call through the interface, namespace, or mixin - NEVER import another impl directly.**

**Architecture:**
- An impl can call its OWN internal methods (same file)
- An impl MUST use interfaces/namespaces/mixins to interact with OTHER types
- This ensures proper encapsulation and allows interfaces to add cross-cutting concerns

**Correct Pattern:**
```zig
// src/webidl/impls/HTMLParser.zig
const interfaces = @import("interfaces");
const Document = interfaces.Document;
const Element = interfaces.Element;

pub fn parseHTML(allocator: Allocator, html: []const u8) !*Instance {
    // ✅ CORRECT: Call through interfaces
    const doc = try Document.createDocument(allocator);
    const elem = try Element.createElement(allocator, "div");
    // ...
}
```

**Wrong Pattern:**
```zig
// src/webidl/impls/HTMLParser.zig
const DocumentImpl = @import("Document.zig");
const ElementImpl = @import("Element.zig");

pub fn parseHTML(allocator: Allocator, html: []const u8) !*Instance {
    // ❌ WRONG: Direct impl-to-impl calls
    const doc = try DocumentImpl.createDocument(allocator);
    const elem = try ElementImpl.createElement(allocator, "div");
    // ...
}
```

**Why This Matters:**
- Interfaces may add CEReactions, validation, or other cross-cutting concerns
- Direct impl calls bypass these important behaviors
- Maintains consistent API surface throughout the codebase
- Allows interfaces to evolve independently of impls

**Scope of Violation (53 files, 245 instances):**
- DOM impls: Document, Element, Node, Attr, CharacterData, etc.
- Streams impls: ReadableStream, WritableStream, TransformStream, controllers, readers
- Other impls: HTMLParser, Range, Selection, Request, Response, etc.

See epic `whatwg-jwgc` for the full list and refactoring plan.

### 15. **Record Non-Trivial Learnings to Cog** ⭐
After fixing bugs or discovering unexpected behavior, use `cog_remember` to persist:
- Root causes that weren't obvious
- Gotchas and pitfalls others might hit
- Patterns that could recur in this codebase

**Rule of thumb:** If you spent more than a few minutes figuring something out, it's worth recording. The debugging time you save future sessions pays for the seconds it takes to record.

**Don't forget to link:** After creating engrams, query for related concepts and use `cog_associate` to connect new knowledge to existing engrams. Isolated engrams won't surface in future queries.

---

## Critical Project Context

### What Makes This Monorepo Special

1. **Multiple Interdependent Specs** - WHATWG specs reference each other extensively (URL uses Infra, Fetch uses Streams, etc.)
2. **Browser Compatibility Foundation** - These specs define how the web works - must match browser behavior exactly
3. **Spec Compliance Critical** - Bugs in any spec affect web platform compatibility
4. **Complex Algorithms** - Parsers, state machines, and data transformations with intricate edge cases
5. **Cross-Language Bridge** - Zig implementations must match JavaScript/browser semantics

### Code Quality

- Production-ready codebase (comprehensive test coverage for stream operations)
- Zero tolerance for memory leaks
- Zero tolerance for breaking changes without major version
- Zero tolerance for untested code
- Zero tolerance for missing or incomplete documentation
- Zero tolerance for deviating from Streams spec

### ⚠️ CRITICAL: Commit After Every Logical Step

**Before following any workflow below, internalize this rule:**

**✅ COMMIT FREQUENTLY** - After every working, tested change:
- Completed a feature → Commit
- Fixed a bug → Commit  
- Added tests that pass → Commit
- Refactored a module → Commit
- Updated documentation → Commit

**DON'T accumulate changes.** Small, focused commits are better than large ones. See Golden Rule #7.

---

### Workflow (New Features)

1. **⚠️ Query Cog FIRST** - Before anything else, check for prior knowledge (see Golden Rule #0):
   ```
   cog_recall({"query": "relevant component keywords", "expand": true})
   ```
2. **Identify context** - Determine which spec you're implementing (from file path or task description)
3. **Read spec** - Load complete spec from `specs/whatwg/[spec-name]/` or relevant spec directory
4. **Understand full algorithm** - Read all steps with context, dependencies, and edge cases
5. **Check dependencies** - Use `monorepo_navigation` skill to find required specs in `src/`
6. **Handle missing dependencies** - Create temporary mocks if needed using `dependency_mocking` skill
7. **Write tests first** - Test all algorithm steps and edge cases
8. **Implement precisely** - Follow spec steps exactly, numbered comments
9. **Document** - Inline docs with spec references (do this BEFORE committing)
10. **Verify** - No leaks, all tests pass, pre-commit checks pass
11. **✅ COMMIT** - Implementation + tests + inline docs together (see Golden Rule #8)
12. **Record learnings to Cog** - If you discovered non-obvious patterns, gotchas, or architectural insights, use `cog_remember` and link to existing concepts (see Golden Rule #15)
13. **Update CHANGELOG.md** - Document what was added
14. **✅ COMMIT** - Commit changelog update
15. **Update FEATURE_CATALOG.md** if user-facing API
16. **✅ COMMIT** - Commit catalog update

**Remember:** Commit after EACH working step. Implementation + tests + docs = ONE commit. Changelog and catalog are separate commits.

### Workflow (Bug Fixes)

1. **⚠️ Query Cog FIRST** - Before anything else, check for prior knowledge about this area (see Golden Rule #0):
   ```
   cog_recall({"query": "component name error type keywords", "expand": true})
   ```
2. **Identify context** - Determine which spec has the bug
3. **Write failing test** that reproduces the bug
4. **Read spec** - Load relevant spec from `specs/whatwg/` to verify expected behavior
5. **Fix the bug** with minimal code change
6. **Document** - Add/update inline docs if needed
7. **Verify** all tests pass (including new test), pre-commit checks pass
8. **✅ COMMIT** - Fix + test + docs together with clear description
9. **Record learnings to Cog** - If you discovered a non-obvious root cause, gotcha, or recurring pattern, use `cog_remember` and link to existing concepts (see Golden Rule #15)
10. **Update** CHANGELOG.md if user-visible
11. **✅ COMMIT** - Commit changelog update

**Remember:** Commit after EACH working step. Fix + test + docs = ONE commit. Changelog is separate.

---

## Memory Tool Usage

Use Claude's memory tool to persist knowledge across sessions:

**Store in memory:**
- Completed WebIDL features with implementation dates
- Design decisions and architectural rationale
- Performance optimization notes
- Complex spec interpretation notes (type conversion edge cases, parser ambiguities)
- Known gotchas and edge cases

**Memory directory structure:**
```
memory/
├── completed_features.json
├── design_decisions.md
└── spec_interpretations.md
```

---

## Quick Reference

### Monorepo Structure

| Directory | Spec | Status | Dependencies |
|-----------|------|--------|--------------|
| `src/url/` | URL Standard | Implemented | Infra, WebIDL |
| `src/encoding/` | Encoding Standard | Implemented | Infra, WebIDL |
| `src/console/` | Console Standard | Implemented | WebIDL |
| `src/mimesniff/` | MIME Sniffing | Implemented | Infra |
| `src/webidl/` | WebIDL | Implemented | - |
| `src/infra/` | Infra Standard | Implemented | - |
| `src/streams/` | Streams Standard | Implemented | Infra, WebIDL |

### Common Patterns

**URL Parsing:**
```zig
const url = try URL.parse(allocator, "https://example.com:8080/path?query#fragment");
defer url.deinit();

const scheme = url.scheme; // "https"
const host = url.host.?.domain; // "example.com"
const port = url.port.?; // 8080
```

**Encoding/Decoding:**
```zig
const decoded = try decoder.decode(allocator, input);
defer allocator.free(decoded);

const encoded = try encoder.encode(allocator, text);
defer allocator.free(encoded);
```

**Stream Operations:**
```zig
var stream = try ReadableStream.init(allocator, .{ .pull = myPullFn });
defer stream.deinit();

const reader = try stream.getReader();
defer reader.releaseLock();

const result = try reader.read();
if (!result.done) {
    // Process result.value
}
```

### Common Error Patterns

```zig
// WHATWG specs use specific error types
pub const SpecError = error{
    // Parsing errors
    TypeError,
    RangeError,
    SyntaxError,
    
    // State errors
    InvalidState,
    
    // Memory errors
    OutOfMemory,
};
```

---

## File Organization

```
skills/
├── whatwg/                  # ⭐ WHATWG spec reading + Zig implementation
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── zig/                     # ⭐ Modern Zig: quality, performance, testing, docs
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── communication_protocol/  # ⭐ Ask clarifying questions when unclear
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── browser_benchmarking/    # Benchmarking strategies
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── pre_commit_checks/       # Automated quality checks
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── monorepo_navigation/     # ⭐ Finding dependencies in monorepo
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
├── dependency_mocking/      # ⭐ Creating temporary mocks
│   ├── USAGE.md             # When to use (autodiscovery)
│   └── SKILL.md             # Complete documentation
└── webidl_codegen/          # ⭐ WebIDL code generation
    ├── USAGE.md             # When to use (autodiscovery)
    └── SKILL.md             # Complete documentation

specs/                       # Complete WHATWG specifications
├── whatwg/                  # WHATWG spec markdown files
│   ├── html/                # HTML Standard files
│   └── ...                  # Other WHATWG specs
├── idl/                     # Symlink to /Users/bcardarella/projects/webref/ed/idl/
│   │                        # Contains all official WHATWG WebIDL definitions
│   │                        # Used as source for code generation (333 IDL files)
│   ├── accelerometer.idl
│   ├── ambient-light.idl
│   └── ...
├── algorithms/              # Algorithm definitions (JSON files)
│   ├── accelerometer.json
│   └── ...
└── supplementary/           # Supplementary WebIDL definitions
    ├── PostMessageOptions.idl
    └── XRFeatureInit.idl

src/                         # Source code (organized by spec)
├── url/                     # URL Standard implementation
├── encoding/                # Encoding Standard implementation
├── console/                 # Console Standard implementation
├── mimesniff/               # MIME Sniffing implementation
├── webidl/                  # WebIDL implementation
├── infra/                   # Infra Standard implementation
├── streams/                 # Streams Standard implementation
└── root.zig                 # Monorepo root

memory/                      # Persistent knowledge (memory tool)
├── completed_features.json
├── design_decisions.md
└── spec_interpretations.md

tests/
└── *.zig                    # Unit tests and integration tests

Root:
├── CHANGELOG.md
├── FEATURE_CATALOG.md       # Complete API reference
├── CONTRIBUTING.md
├── AGENTS.md (this file)
└── build.zig, build.zig.zon
```

---

## Temporary Files Policy

**CRITICAL: Temporary files MUST go into `tmp/` directory, NOT project root.**

**DEFAULT BEHAVIOR: ALL AI-generated documents go to `tmp/` unless user explicitly requests otherwise.**

**See `skills/temporary_files/SKILL.md` for complete policy and detailed guidelines.**

### Quick Summary

**Organized subdirectories:**
- `tmp/summaries/` - Session summaries, completion reports
- `tmp/analysis/` - Investigation notes, code analysis
- `tmp/plans/` - Implementation plans, design docs
- `tmp/debug/` - Debug output, test results
- `tmp/scratch/` - Any other temporary work

### Directory Usage Guide

| Directory | Purpose | Gitignored? | Examples |
|-----------|---------|-------------|----------|
| `tmp/summaries/` | Session summaries | **Required** | session_2025-11-17.md, epic_summary.md |
| `tmp/analysis/` | Investigation work | **Required** | duplicate_warnings_analysis.md |
| `tmp/plans/` | Design documents | **Required** | typedef_generation_design.md |
| `tmp/debug/` | Debug output | **Required** | test_results.txt, performance_report.md |
| `tmp/scratch/` | Other temporary | **Required** | quick_notes.md |
| Root | Permanent project docs | No | README.md, CHANGELOG.md, CONTRIBUTING.md |

### Rules for Temporary Files

**DEFAULT BEHAVIOR: ALL AI-generated documents go to `tmp/` unless user explicitly requests otherwise.**

1. **✅ All temporary files MUST go in `tmp/` BY DEFAULT**
   - Session summaries and completion reports → `tmp/summaries/`
   - Investigation notes and analysis → `tmp/analysis/`
   - Implementation plans and design docs → `tmp/plans/`
   - Debug output and test results → `tmp/debug/`
   - Scratch scripts and utilities → `tmp/scratch/`
   - **This includes:** planning docs, summaries, analyses, debug output, temporary scripts
   - **Exception:** ONLY when user explicitly requests a different location

2. **✅ `tmp/` directory MUST be gitignored**
   - Verify `.gitignore` includes `/tmp/` 
   - Create directory if it doesn't exist
   - Never commit temporary files

3. **⚠️ Project root is ONLY for user-requested permanent documentation**
   - User must explicitly say: "create this in the root" OR "this should be committed"
   - Examples: "Add MIGRATION_GUIDE.md to the root", "Create permanent design doc"
   - Do NOT assume files belong in root just because they seem important

### Examples

**❌ WRONG - Writing to project root:**
```
ENCODING_MIXIN_ANALYSIS.md          # ❌ Should be tmp/encoding_mixin_analysis.md
INVESTIGATION_NOTES.md              # ❌ Should be tmp/investigation_notes.md
/tmp/test_something.zig             # ❌ Wrong tmp location
```

**✅ CORRECT - Writing to tmp/:**
```
tmp/encoding_mixin_analysis.md      # ✅ Temporary analysis
tmp/investigation_notes.md          # ✅ Temporary notes
tmp/test_something.zig              # ✅ Temporary test script
tmp/debug_helper.sh                 # ✅ Temporary shell script
```

**✅ CORRECT - Permanent files (when explicitly requested):**
```
WEBIDL_MIXIN_GUIDELINES.md          # ✅ Permanent reference (explicitly requested)
CHANGELOG.md                         # ✅ Project documentation
CONTRIBUTING.md                      # ✅ Project documentation
```

### When User Explicitly Requests Root Location

**Only place files in project root when user explicitly says:**
- "Create a permanent reference document in the root"
- "Add this to the project documentation"
- "This should be committed to the repo"

**Otherwise, default to `tmp/` for all generated content.**

### Workflow

Before creating any markdown or script file:

1. **Determine file type and longevity**
   - Temporary scratch work? → `tmp/` (required gitignore)
   - Long-term planning? → `history/` (optional gitignore)
   - Permanent project docs? → Root (only if user explicitly requests)

2. **Verify directory exists and gitignore is correct**
   ```bash
   mkdir -p tmp
   grep -q "^/tmp/" .gitignore || echo "/tmp/" >> .gitignore
   
   # Optional: for history/ if user wants it gitignored
   mkdir -p history
   grep -q "^/history/" .gitignore || echo "/history/" >> .gitignore
   ```

3. **Create file in appropriate location**

### Examples

**❌ WRONG - Writing to project root:**
```
ENCODING_MIXIN_ANALYSIS.md          # ❌ Should be tmp/analysis/encoding_mixin_analysis.md
INVESTIGATION_NOTES.md              # ❌ Should be tmp/analysis/investigation_notes.md
SESSION_SUMMARY.md                  # ❌ Should be tmp/summaries/session_summary.md
PLAN.md                             # ❌ Should be tmp/plans/plan.md
```

**✅ CORRECT - Writing to tmp/:**
```
tmp/analysis/encoding_mixin_analysis.md  # ✅ Temporary analysis
tmp/analysis/investigation_notes.md      # ✅ Temporary notes
tmp/summaries/session_summary.md         # ✅ Session summary
tmp/plans/plan.md                        # ✅ Implementation plan
tmp/debug/test_results.txt               # ✅ Debug output
tmp/scratch/helper.sh                    # ✅ Temporary script
```

**✅ CORRECT - Permanent files (when explicitly requested):**
```
WEBIDL_MIXIN_GUIDELINES.md          # ✅ Permanent reference (explicitly requested)
CHANGELOG.md                         # ✅ Project documentation
CONTRIBUTING.md                      # ✅ Project documentation
```

### Why This Matters

- **Keeps repository clean** - No clutter from investigation files
- **Prevents accidental commits** - Temporary analysis doesn't get committed
- **Clear separation** - Permanent vs temporary documentation
- **User control** - User decides what becomes permanent

---

## Zero Tolerance For

- Memory leaks (test with `std.testing.allocator`)
- Breaking changes without major version bump
- Untested code
- Missing documentation
- Undocumented CHANGELOG entries
- **Deviating from WHATWG spec algorithms**
- **Browser incompatibility** (test against browser implementations)
- **Missing spec references** (must cite WHATWG spec section)
- **Incorrect cross-spec behavior** (dependencies must be handled correctly)
- **Unmarked temporary mocks** (all mocks must have clear TODO markers)
- **Generated files in project root** (must use `tmp/` unless explicitly requested otherwise)
- **Accumulating uncommitted changes** (commit after every logical unit of work)
- **Modifying generated files directly** (changes must go through codegen source files)
- **Calling impls directly from external code** (must go through interfaces - see Golden Rule #12)
- **Impls calling other impls directly** (must go through interfaces - see Golden Rule #13)

---

## Dependencies

### Internal Dependencies (Within Monorepo)

Most WHATWG specs depend on other WHATWG specs implemented in this monorepo:

**Finding Internal Dependencies:**
1. **Use `monorepo_navigation` skill** - Automatically detects and locates dependencies
2. **Check `src/` directory** - Each spec has its own subdirectory
3. **Import patterns** - `@import("url")`, `@import("infra")`, etc.

**Common Dependency Patterns:**
- Most specs depend on **Infra** (`src/infra/`) - strings, bytes, lists, ordered maps
- Specs with Web APIs depend on **WebIDL** (`src/webidl/`) - type system
- URL, Fetch, and others depend on each other

**If Dependency Not Implemented:**
1. **Use `dependency_mocking` skill** - Create temporary mock with clear markers
2. **Mark as TODO** - Indicate this must be replaced with real implementation

### Internal WebIDL Codegen

The WebIDL code generation system is built-in to this monorepo at `src/webidl/codegen/`.

**How it works:**
- Source files in `webidl/src/**/*.zig` use `webidl.interface()`, `webidl.namespace()`, or `webidl.mixin()`
- Run `zig build codegen` to generate enhanced code in `webidl/generated/**/*.zig` (gitignored)
- Generated files have flattened inheritance, optimized layouts, and property accessors
- Uses SHA-256 hashing for fast incremental builds

**Key APIs:**
- `webidl.interface(struct { ... })` - WebIDL interface (can have instances, inheritance)
- `webidl.namespace(struct { ... })` - WebIDL namespace (static-only operations)
- `webidl.mixin(struct { ... })` - WebIDL interface mixin (reusable member bundles)

**See:** `skills/webidl_codegen/SKILL.md` for complete documentation

---

## When in Doubt

1. **ASK A CLARIFYING QUESTION** ⭐ - Don't assume, just ask (one question at a time)
2. **Have you committed recently?** ⭐⭐⭐ - If you have working changes, commit them NOW
3. **Creating files?** - Put generated docs/scripts in `tmp/` unless explicitly requested otherwise
4. **Identify context** - Which spec are you working on? (file path, imports)
5. **Read the WHATWG spec** - Load complete spec from `specs/whatwg/[spec-name]/`
6. **Read the complete section** - Context matters, never rely on fragments
7. **Check dependencies** - Use `monorepo_navigation` to find implementations
8. **Load relevant skills** - Get specialized, context-aware guidance
9. **Look at existing tests** - See patterns in similar specs
10. **Check FEATURE_CATALOG.md** - See existing API patterns
11. **Follow the Golden Rules** - Especially algorithm precision, committing, and dependency handling

---

## WHATWG Standards Reference

**Official WHATWG Website**: https://whatwg.org/

**Specification Links** (commonly used in this monorepo):

| Spec | Official URL | Local Directory |
|------|--------------|-----------------|
| **URL** | https://url.spec.whatwg.org/ | `specs/whatwg/url/` |
| **Encoding** | https://encoding.spec.whatwg.org/ | `specs/whatwg/encoding/` |
| **Streams** | https://streams.spec.whatwg.org/ | `specs/whatwg/streams/` |
| **Infra** | https://infra.spec.whatwg.org/ | `specs/whatwg/infra/` |
| **WebIDL** | https://webidl.spec.whatwg.org/ | `specs/whatwg/webidl/` |
| **Console** | https://console.spec.whatwg.org/ | `specs/whatwg/console/` |
| **MIME Sniff** | https://mimesniff.spec.whatwg.org/ | `specs/whatwg/mimesniff/` |
| **Fetch** | https://fetch.spec.whatwg.org/ | `specs/whatwg/fetch/` |
| **DOM** | https://dom.spec.whatwg.org/ | `specs/whatwg/dom/` |

**Reading Guide** (applies to all specs):
1. **Identify the spec** - Know which spec you're implementing
2. **Load complete sections** - Read full algorithms with context
3. **Check cross-references** - Specs reference each other frequently
4. **Read all algorithm steps** - Don't skip any steps
5. **Test against browsers** - Verify behavior matches Chrome, Firefox, Safari

**Context Detection**:
- The skills will automatically detect which spec you're working on from file paths
- Use `whatwg_spec` skill for spec-specific guidance
- Use `monorepo_navigation` skill to find related implementations

---

## Lessons Learned

### Codegen: Always Regenerate From Scratch to Find Systemic Issues

**Date**: 2025-11-22  
**Lesson**: When debugging codegen issues, always delete generated files and regenerate completely from scratch.

**Why**: Partial regeneration can mask systemic issues because:
- Impl files are protected from overwriting
- Old files with wrong signatures persist
- Incremental fixes hide root causes

**What Happened**:
- Had 12 type mismatch errors between interface and impl files
- Interface: `call_start(instance, when, offset, duration)` - 3 params
- Impl: `call_start(instance, when)` - 1 param
- Thought it was optional parameter handling issue
- **Root cause**: Impl generator used `all_ops` (inherited + own) while interface used `own_ops` (own only)
- When `deduplicateOperations()` ran on `all_ops`, it kept FIRST occurrence (parent's signature) and discarded child's override

**Fix**:
1. Changed impl stub generator to collect ONLY own operations (not inherited)
2. Added overload-aware generation using same logic as interface
3. Result: Impl signatures now EXACTLY match interface signatures

**Takeaway**: **Regenerate from scratch** exposes systemic architectural issues that incremental fixes hide.

---

### Codegen: Interface and Impl Must Use Same Signature Generation

**Date**: 2025-11-22  
**Lesson**: Interface files and impl stub files MUST use the EXACT same method for generating function signatures.

**Rule**: If interface uses `own_operations` for delegate functions, impl stubs MUST also use `own_operations` (not `all_ops`).

**Why**: 
- Interface files delegate to impl files
- Signature mismatch = compilation error
- Different operation lists = different signatures

**Pattern**:
```zig
// Interface generation (writer.zig)
try writer.writeDelegateFunctions(w, impl_name, type_reg, 
    own_attrs.items,  // ← ONLY own attributes
    own_ops.items     // ← ONLY own operations
);

// Impl generation (generator.zig) - MUST match
for (interface.members) |member| {  // ← ONLY own members
    switch (member.type) {
        .attribute => try all_attrs.append(allocator, attr),
        .operation => try all_ops.append(allocator, op),
        // NOT: Use IR to get all members (inherited + own)
    }
}
```

**Verification**: After codegen changes, always:
1. Delete generated files in `src/webidl/` subdirectories completely
2. Regenerate with `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
3. Run `zig build` to verify no type mismatches

---

### Codegen: Deduplication Must Preserve All Overload Variants

**Date**: 2025-11-22  
**Lesson**: When deduplicating operations, preserve ALL overload variants, not just the first occurrence.

**Wrong**:
```zig
fn deduplicateOperations(allocator: std.mem.Allocator, ops: *std.ArrayList(types.Operation)) !void {
    for (ops.items) |op| {
        const op_name = op.name orelse continue;
        if (!seen.contains(op_name)) {
            try unique.append(allocator, op);  // ← Keeps FIRST, discards overloads!
            try seen.put(op_name, {});
        }
    }
}
```

**Right**: Use overload-aware grouping
```zig
const overload_sets = try overload.groupOperationsByName(allocator, operations);
// Generates tagged union for overloaded methods
// Generates single function for non-overloaded methods
```

**Impact**: 
- Wrong approach loses method overrides (child vs parent)
- Wrong approach loses true overloads (different parameter types)
- Right approach preserves all variants and generates correct code

---

### Debugging: Ask User to Regenerate When Suspecting Stale Files

**Date**: 2025-11-22  
**Lesson**: When encountering mysterious errors, ask user to delete and regenerate to rule out stale files.

**Pattern**:
```
User: "I'm getting type mismatch errors"
Agent: "I want to first try to regenerate all of the files,
        delete the generated files in src/webidl/ subdirectories first then see if the problem still exists"
```

**Why This Works**:
- Rules out stale file issues immediately
- Exposes systemic problems vs one-off bugs  
- User insight often reveals architectural issues agent might miss

**Saved Time**: Instead of investigating 12 individual type mismatches, user's suggestion exposed the root cause in one regeneration.

---

## ⚠️ DIRECTIVE: Expand AGENTS.md When You Learn

**When you learn something new or find a better way to do something, you MUST update this file.**

### What to Add

Add new lessons when you:
1. **Discover a bug pattern** that could happen again
2. **Find a better approach** to a common task
3. **Learn from user feedback** about correct methodology
4. **Identify a systemic issue** vs one-off bug
5. **Establish a new best practice** for this codebase

### How to Add

1. **Add to "Lessons Learned" section** (above)
2. **Include date** (YYYY-MM-DD format)
3. **Describe the problem** clearly
4. **Explain the solution** with code examples if relevant
5. **State the takeaway** - what should be done differently next time

### Format Template

```markdown
### Category: Brief Lesson Title

**Date**: YYYY-MM-DD  
**Lesson**: One-sentence summary of what was learned.

**Why**: Explanation of the underlying issue.

**What Happened**: 
- Context of the problem
- What went wrong
- How it manifested

**Fix**:
1. Step-by-step solution
2. Code examples if relevant

**Takeaway**: **Bold key insight** that should guide future work.
```

### Categories

- **Codegen**: Code generation patterns and pitfalls
- **Debugging**: Investigation and diagnosis techniques  
- **Architecture**: System design and structure
- **Testing**: Test strategy and coverage
- **Workflow**: Development process improvements
- **Spec Compliance**: WHATWG spec interpretation

**This file is a living document.** Keep it updated as the project evolves and knowledge accumulates.

---

**Quality over speed.** Take time to do it right. The codebase is production-ready and must stay that way.

**Skills are context-aware.** They adapt to the spec you're working on. Load skills for deep expertise.

**WHATWG specs define the web.** Browser compatibility depends on correct implementations. Precision matters.

**Cross-spec dependencies matter.** Use `monorepo_navigation` and `dependency_mocking` skills to handle them correctly.

**Document what you learn.** Future agents (and humans) will thank you for expanding this file when you discover better approaches.

**Thank you for maintaining the high quality standards of this project!** 🎉
