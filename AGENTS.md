We track work in Beads instead of Markdown. Run \`bd quickstart\` to see how.

# Agent Guidelines for WHATWG Specifications Monorepo in Zig

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

### Core Principles

1. **Spec Compliance** - Every implementation must match the WHATWG specification exactly
2. **Browser Compatibility** - Behavior must match Chrome, Firefox, and Safari
3. **Memory Safety** - Zero tolerance for leaks, use Zig idioms (defer, allocators)
4. **Comprehensive Testing** - All algorithms tested with edge cases and WPT tests
5. **Cross-Spec Dependencies** - Specs reference each other (e.g., URL uses Infra, Fetch uses Streams)

### Monorepo Structure

```
src/
├── console/       # Console Standard
├── encoding/      # Encoding Standard  
├── infra/         # Infra Standard (primitives used by other specs)
├── mimesniff/     # MIME Sniffing Standard
├── streams/       # Streams Standard
├── url/           # URL Standard
└── webidl/        # WebIDL (type system for all specs)

specs/            # Complete specification markdown files
tests/            # Cross-spec integration tests
```

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

This project uses **Agent Skills** for specialized knowledge areas. Skills are automatically loaded when relevant to your task.

## WHATWG Specifications

**Complete specifications are available in `specs/` directory:**

Each spec has markdown and/or IDL files:
- `specs/url.md` - URL Standard specification
- `specs/encoding.md` - Encoding Standard specification
- `specs/streams.md` - Streams Standard specification
- `specs/infra.md` - Infra Standard specification
- `specs/webidl.md` - WebIDL specification
- `specs/console.md` - Console Standard specification
- `specs/mimesniff.md` - MIME Sniffing Standard specification
- And many more...

**Always load complete spec sections** from these files into context when implementing features:
- **Markdown files** (`.md`) - Algorithms, state machines, and implementation details
- **IDL files** (`.idl`) - Interface definitions, method signatures, and API contracts (when available)

Never rely on grep fragments - every algorithm has context and edge cases that matter.

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

---

## Available Skills

**Skills are autodiscovered** from the `skills/` directory. Each skill has a `USAGE.md` file that explains when to use it.

### Discovering Skills

**To see all available skills**, scan the `skills/` directory for subdirectories containing `USAGE.md` files:

```bash
ls -d skills/*/
```

**To learn when to use a skill**, read its `USAGE.md`:

```bash
# Example: Learn about the whatwg skill
cat skills/whatwg/USAGE.md

# Example: Learn about the zig skill
cat skills/zig/USAGE.md
```

### Skill Loading

Skills are **automatically loaded** based on:
- **File path context** (e.g., working in `src/url/` loads `whatwg` skill)
- **Task type** (e.g., writing tests loads `zig` skill)
- **Explicit need** (e.g., cross-spec dependencies load `monorepo_navigation` skill)

**You should proactively scan `skills/` to understand available skills and when to use each one.**

### Skill Structure

Each skill directory contains:
- `USAGE.md` - **Concise** guide on when to use the skill (read this first)
- `SKILL.md` - **Comprehensive** documentation with patterns and examples (read when using the skill)

### How to Use Skills

1. **Scan `skills/` directory** - See all available skills
2. **Read `USAGE.md` files** - Understand when each skill applies
3. **Load relevant skill** - Read full `SKILL.md` when you need detailed guidance
4. **Apply patterns** - Use skill-specific patterns and examples


## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**
```bash
bd ready --json
```

**Create new issues:**
```bash
bd create "Issue title" -t bug|feature|task -p 0-4 --json
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**
```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**
```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`
6. **Commit together**: Always commit the `.beads/issues.jsonl` file together with the code changes so issue state stays in sync with code state

### Auto-Sync

bd automatically syncs with git:
- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### MCP Server (Recommended)

If using Claude or MCP-compatible clients, install the beads MCP server:

```bash
pip install beads-mcp
```

Add to MCP config (e.g., `~/.config/claude/config.json`):
```json
{
  "beads": {
    "command": "beads-mcp",
    "args": []
  }
}
```

Then use `mcp__beads__*` functions instead of CLI commands.

### Managing AI-Generated Planning Documents

AI assistants often create planning and design documents during development:
- PLAN.md, IMPLEMENTATION.md, ARCHITECTURE.md
- DESIGN.md, CODEBASE_SUMMARY.md, INTEGRATION_PLAN.md
- TESTING_GUIDE.md, TECHNICAL_DESIGN.md, and similar files

**Best Practice: Use a dedicated directory for these ephemeral files**

**Recommended approach:**
- Create a `history/` directory in the project root
- Store ALL AI-generated planning/design docs in `history/`
- Keep the repository root clean and focused on permanent project files
- Only access `history/` when explicitly asked to review past planning

**Example .gitignore entry (optional):**
```
# AI planning documents (ephemeral)
history/
```

**Benefits:**
- ✅ Clean repository root
- ✅ Clear separation between ephemeral and permanent documentation
- ✅ Easy to exclude from version control if desired
- ✅ Preserves planning history for archeological research
- ✅ Reduces noise when browsing the project

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ✅ Store AI planning docs in `history/` directory
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems
- ❌ Do NOT clutter repo root with planning documents

For complete details, see `skills/beads_workflow/SKILL.md`.

---

## Golden Rules

These apply to ALL work on this project:

### 0. **Ask When Unclear** ⭐
When requirements are ambiguous or unclear, **ASK CLARIFYING QUESTIONS** before proceeding. One question at a time. Wait for answer. Never assume.

### 1. **Complete Spec Understanding**
Load the complete WHATWG specification from `specs/` into context. Read the full algorithm sections with proper context. Never rely on grep fragments - every algorithm has context and edge cases.

### 2. **Algorithm Precision**
WHATWG specs define web platform behavior. Implement EXACTLY as specified, step by step. Even small deviations can break compatibility with browsers and cause unexpected behavior.

### 3. **Memory Safety**
Zero leaks, proper cleanup with defer, test with `std.testing.allocator`. No exceptions. Every allocation must have a corresponding deinit or free.

### 4. **Test First**
Write tests before implementation. Comprehensive unit testing for all algorithm steps, edge cases, and error conditions.

### 5. **Browser Compatibility**
Implementations must match browser behavior. Test against edge cases and boundary conditions. When in doubt, check how browser implementations (Chrome, Firefox, Safari) handle it.

### 6. **Performance Matters** (but spec compliance comes first)
WHATWG specs underpin all web platform functionality. Optimize for performance where possible. But never sacrifice correctness for speed.

### 7. **Commit Frequently** ⭐⭐⭐
**COMMIT AFTER EVERY LOGICAL UNIT OF WORK.** This is non-negotiable. Do not accumulate changes. Commit when you:
- Complete a feature or fix
- Finish refactoring a module
- Add tests that pass
- Update documentation
- Make any working, tested change

**Use descriptive commit messages** following the project's conventional commit style. See "Workflow" sections below for commit procedures.

### 8. **Use bd for Task Tracking** ⭐
All tasks, bugs, and features tracked in bd (beads). Always use `bd ready --json` to check for work. Link discovered issues with `discovered-from`. Never use markdown TODOs.

### 9. **Handle Dependencies Correctly** ⭐
When a spec depends on another spec, check `src/` for implementation. If not implemented, create a temporary mock with clear markers. Never skip dependency handling.

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

1. **Check bd for issue** - `bd ready --json` or create new issue if needed
2. **Claim the issue** - `bd update bd-N --status in_progress --json`
3. **Identify context** - Determine which spec you're implementing (from file path or issue description)
4. **Read spec** - Load complete spec from `specs/[spec-name].md`
5. **Understand full algorithm** - Read all steps with context, dependencies, and edge cases
6. **Check dependencies** - Use `monorepo_navigation` skill to find required specs in `src/`
7. **Handle missing dependencies** - Create temporary mocks if needed using `dependency_mocking` skill
8. **Write tests first** - Test all algorithm steps and edge cases
9. **Implement precisely** - Follow spec steps exactly, numbered comments
10. **Verify** - No leaks, all tests pass, pre-commit checks pass
11. **✅ COMMIT** - `git add -A && git commit` with descriptive message (see Golden Rule #7)
12. **Document** - Inline docs with spec references
13. **Update CHANGELOG.md** - Document what was added
14. **✅ COMMIT** - Commit documentation changes
15. **Update FEATURE_CATALOG.md** if user-facing API
16. **✅ COMMIT** - Commit catalog update
17. **Close issue** - `bd close bd-N --reason "Implemented" --json`

**Remember:** Commit after EACH working step. Don't accumulate changes.

### Workflow (Bug Fixes)

1. **Check bd for issue** - or create: `bd create "Bug: ..." -t bug -p 1 --json`
2. **Claim the issue** - `bd update bd-N --status in_progress --json`
3. **Identify context** - Determine which spec has the bug
4. **Write failing test** that reproduces the bug
5. **✅ COMMIT** - Commit the failing test
6. **Read spec** - Load relevant spec from `specs/` to verify expected behavior
7. **Fix the bug** with minimal code change
8. **Verify** all tests pass (including new test), pre-commit checks pass
9. **✅ COMMIT** - Commit the fix with clear description
10. **Update** CHANGELOG.md if user-visible
11. **✅ COMMIT** - Commit changelog update
12. **Close issue** - `bd close bd-N --reason "Fixed" --json`

**Remember:** Commit after EACH working step. Don't accumulate changes.

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
├── beads_workflow/          # ⭐ Task tracking with bd (beads)
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

specs/                       # Complete WHATWG specification files
├── url.md                   # URL Standard
├── encoding.md              # Encoding Standard
├── streams.md               # Streams Standard
├── infra.md                 # Infra Standard
├── webidl.md                # WebIDL specification
├── console.md               # Console Standard
├── mimesniff.md             # MIME Sniffing Standard
├── fetch.md                 # Fetch Standard
├── dom.md                   # DOM Standard
└── ... (many more specs)

src/                         # Source code (organized by spec)
├── url/                     # URL Standard implementation
├── encoding/                # Encoding Standard implementation
├── console/                 # Console Standard implementation
├── mimesniff/               # MIME Sniffing implementation
├── webidl/                  # WebIDL implementation
├── infra/                   # Infra Standard implementation
├── streams/                 # Streams Standard implementation
└── root.zig                 # Monorepo root

.beads/
└── issues.jsonl             # Beads issue tracking database (git-versioned)

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

**CRITICAL: All generated documentation and temporary files MUST go into `tmp/` directory.**

### Rules for Temporary Files

**Unless explicitly requested otherwise by the user:**

1. **✅ All generated markdown files MUST go in `tmp/`**
   - Analysis documents
   - Summary reports
   - Investigation notes
   - Scratch documentation
   - **Exception:** Only permanent documentation explicitly requested for project root

2. **✅ All temporary scripts MUST go in `tmp/`**
   - Test scripts
   - Debug utilities
   - One-off automation scripts
   - Investigation helpers
   - **Exception:** Only permanent tools explicitly requested for project structure

3. **✅ `tmp/` directory MUST be gitignored**
   - Verify `.gitignore` includes `/tmp/` 
   - Create directory if it doesn't exist
   - Never commit temporary files

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

1. **Check if user explicitly requested permanent location**
   - If yes → Create in requested location
   - If no → Create in `tmp/`

2. **Verify `tmp/` exists and is gitignored**
   ```bash
   mkdir -p tmp
   grep -q "^/tmp/" .gitignore || echo "/tmp/" >> .gitignore
   ```

3. **Create file in appropriate location**

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
3. **Track in bd** - Create issue to implement the dependency

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
2. **Check bd for existing issues** - `bd ready --json` - See if work is already tracked
3. **Have you committed recently?** ⭐⭐⭐ - If you have working changes, commit them NOW
4. **Creating files?** - Put generated docs/scripts in `tmp/` unless explicitly requested otherwise
5. **Identify context** - Which spec are you working on? (file path, imports)
6. **Read the WHATWG spec** - Load complete spec from `specs/[spec-name].md`
7. **Read the complete section** - Context matters, never rely on fragments
8. **Check dependencies** - Use `monorepo_navigation` to find implementations
9. **Load relevant skills** - Get specialized, context-aware guidance
10. **Look at existing tests** - See patterns in similar specs
11. **Check FEATURE_CATALOG.md** - See existing API patterns
12. **Follow the Golden Rules** - Especially algorithm precision, committing, and dependency handling

---

## WHATWG Standards Reference

**Official WHATWG Website**: https://whatwg.org/

**Specification Links** (commonly used in this monorepo):

| Spec | Official URL | Local File |
|------|--------------|------------|
| **URL** | https://url.spec.whatwg.org/ | `specs/url.md` |
| **Encoding** | https://encoding.spec.whatwg.org/ | `specs/encoding.md` |
| **Streams** | https://streams.spec.whatwg.org/ | `specs/streams.md` |
| **Infra** | https://infra.spec.whatwg.org/ | `specs/infra.md` |
| **WebIDL** | https://webidl.spec.whatwg.org/ | `specs/webidl.md` |
| **Console** | https://console.spec.whatwg.org/ | `specs/console.md` |
| **MIME Sniff** | https://mimesniff.spec.whatwg.org/ | `specs/mimesniff.md` |
| **Fetch** | https://fetch.spec.whatwg.org/ | `specs/fetch.md` |
| **DOM** | https://dom.spec.whatwg.org/ | `specs/dom.md` |

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

**Quality over speed.** Take time to do it right. The codebase is production-ready and must stay that way.

**Skills are context-aware.** They adapt to the spec you're working on. Load skills for deep expertise.

**WHATWG specs define the web.** Browser compatibility depends on correct implementations. Precision matters.

**Cross-spec dependencies matter.** Use `monorepo_navigation` and `dependency_mocking` skills to handle them correctly.

**Thank you for maintaining the high quality standards of this project!** 🎉
