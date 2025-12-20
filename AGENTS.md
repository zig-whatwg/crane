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

**Finding Dependencies**: Check `src/` for existing implementations or create temporary mocks for unimplemented specs.

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

- **Recommended**: Install pre-commit hooks to automate checks
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

### 0. **Ask When Unclear** ⭐
When requirements are ambiguous or unclear, **ASK CLARIFYING QUESTIONS** before proceeding. One question at a time. Wait for answer. Never assume.

### 1. **Complete Spec Understanding**
Load the complete WHATWG specification from `specs/` into context. Read the full algorithm sections with proper context. Never rely on grep fragments - every algorithm has context and edge cases.

### 2. **Algorithm Precision**
WHATWG specs define web platform behavior. Implement EXACTLY as specified, step by step. Even small deviations can break compatibility with browsers and cause unexpected behavior.

### 3. **Memory Safety**
Zero leaks, proper cleanup with defer, test with `std.testing.allocator`. No exceptions. Every allocation must have a corresponding deinit or free.

### 4. **Test Thoroughly**
Write comprehensive tests for all implementations. Test-driven development (TDD) is encouraged but not mandatory. All algorithm steps, edge cases, and error conditions must have test coverage before committing.

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

### 8. **Handle Dependencies Correctly** ⭐
When a spec depends on another spec, check `src/` for implementation. If not implemented, create a temporary mock with clear markers. Never skip dependency handling.

### 9. **All Temporary Files Go to tmp/** ⭐
**DEFAULT: ALL** AI-generated summaries, analyses, plans, and temporary documentation MUST go into `tmp/` directory by default. Never clutter project root. Only place files elsewhere when user explicitly requests it.

### 10. **Use Compile-Time Debug Logging** ⭐
**ALWAYS use the `debug` module for debug output instead of `std.debug.print`.**

The project has a compile-time configurable debug system that completely eliminates debug output from release builds. This means you can leave debug statements in the code - they have zero runtime cost when disabled.

**How to use:**
```zig
const debug = @import("root").debug;

// Basic debug output (general scope)
debug.print("Processing: {s}\n", .{item});

// Scoped debug output (filtered by -Ddebug-scope)
debug.scoped(.v8).print("V8 context: {*}\n", .{ctx});
debug.scoped(.webidl).print("Interface: {s}\n", .{name});
debug.scoped(.dom).print("Node: {d}\n", .{node_type});
```

**Available scopes:** `v8`, `webidl`, `dom`, `css`, `html`, `url`, `encoding`, `streams`, `fetch`, `runtime`, `gc`, `wpt`, `general`

**How to compile with debug output:**
```bash
# Enable all debug output
zig build -Ddebug=true

# Enable only specific scopes (reduces token count)
zig build -Ddebug=true -Ddebug-scope=v8
zig build -Ddebug=true -Ddebug-scope=webidl,dom

# Run tests with debug output
zig build test -Ddebug=true -Ddebug-scope=v8
```

**When debugging:**
1. Add `debug.scoped(.scope).print()` statements as needed
2. Compile with `-Ddebug=true -Ddebug-scope=<scope>` to see output
3. Leave the debug statements in place - they cost nothing when disabled
4. Use specific scopes to reduce noise and token count

**DO NOT use `std.debug.print` directly** - always use the debug module so output can be controlled at compile time.

### 11. **NEVER Modify Generated Files Directly** ⭐⭐⭐ ABSOLUTE RULE ⭐⭐⭐

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🛑🛑🛑 FULL STOP - READ THIS ENTIRE SECTION BEFORE ANY EDIT 🛑🛑🛑        ║
║                                                                              ║
║   This rule exists because it has been VIOLATED and caused WASTED WORK.     ║
║   The violation was REVERTED. Do not repeat the same mistake.               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

## 🚨 STOP! READ THIS BEFORE TOUCHING ANY FILE IN src/webidl/ 🚨

**This is an ABSOLUTE, INVIOLABLE rule. There are NO exceptions. NO workarounds. NO "just this once."**

**Files in `src/webidl/` subdirectories (interfaces/, typedefs/, dictionaries/, callbacks/, enums/, mixins/) are code-generated outputs. You MUST NEVER edit them directly. PERIOD.**

### ⚠️ MANDATORY PATH CHECK - DO THIS FIRST ⚠️

**BEFORE using the Edit tool on ANY .zig file, you MUST:**

```
Step 1: Look at the file path
Step 2: Does the path contain ANY of these?
        - src/webidl/interfaces/
        - src/webidl/typedefs/
        - src/webidl/dictionaries/
        - src/webidl/callbacks/
        - src/webidl/enums/
        - src/webidl/mixins/
        
Step 3: If YES to ANY → 🛑 STOP IMMEDIATELY. DO NOT EDIT.
        If NO → Proceed to Pre-Edit Checklist below.
```

**This path check is NON-NEGOTIABLE. Do it EVERY TIME before ANY edit.**

### Historical Violations (Learn From These Mistakes)

**2025-12-07 Violation (REVERTED in commit ca618b9df):**
- Agent directly edited `src/webidl/interfaces/HTMLScriptElement.zig` adding ~20 delegate methods
- Agent directly edited `src/webidl/interfaces/Document.zig` adding `isScriptingEnabled` delegate
- Agent directly edited `src/webidl/interfaces/ReadableStream.zig` fixing callback signatures
- Agent directly edited `src/webidl/interfaces/WritableStream.zig` fixing callback signatures
- Agent directly edited `src/webidl/interfaces/Response.zig` fixing `call_json_static`
- **Result**: ALL changes had to be reverted. ALL work was wasted. User had to explain the rule.
- **Root cause**: Agent rationalized "it's just a quick fix" and "I'll fix codegen after"

**DO NOT ADD TO THIS LIST. Learn from it.**

### Pre-Edit Checklist (MANDATORY - After Path Check)

**Before editing ANY file, you MUST ask yourself:**

1. **Is this file in `src/webidl/interfaces/`, `src/webidl/typedefs/`, `src/webidl/dictionaries/`, `src/webidl/callbacks/`, `src/webidl/enums/`, or `src/webidl/mixins/`?**
   - **YES** → ❌ **STOP. DO NOT EDIT.** Go to codegen instead.
   - **NO** → Proceed with caution, verify it's not generated.

2. **Does the file have a header comment saying "AUTO-GENERATED"?**
   - **YES** → ❌ **STOP. DO NOT EDIT.** Go to codegen instead.
   - **NO** → May be safe to edit, but verify.

3. **Am I trying to add a "quick fix" or "delegate method" directly?**
   - **YES** → ❌ **STOP. This is EXACTLY the violation this rule prevents.** Go to codegen.
   - **NO** → Verify you're editing the right file.

### What To Do Instead

**When you need to change generated interface behavior:**

1. **Identify the codegen source** in `src/webidl/codegen/`
2. **Modify the codegen** to produce the desired output
3. **Regenerate ALL files**: `zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/`
4. **Verify the change** appears in the regenerated files
5. **Commit BOTH** the codegen changes AND the regenerated files

**When you need internal/non-IDL methods:**

1. **Add support to codegen** for "internal methods" or "extension points"
2. **Or create a separate non-generated module** that interfaces import
3. **NEVER add methods directly to generated interface files**

### Generated File Directories (NEVER EDIT DIRECTLY)

```
src/webidl/
├── interfaces/    ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── typedefs/      ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── dictionaries/  ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── callbacks/     ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── enums/         ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── mixins/        ❌ GENERATED - DO NOT EDIT - EVER - NO EXCEPTIONS
├── codegen/       ✅ EDIT THIS - Source of truth
├── impls/         ✅ EDIT THIS - Custom implementations
└── impls_tmp/     ⚠️ REFERENCE ONLY - Gitignored stubs
```

### Why This Rule Is ABSOLUTE

1. **Generated files are overwritten** on every codegen run - your edits WILL be lost
2. **Manual edits create drift** between codegen and actual files - causes subtle bugs
3. **The codegen is the source of truth** - diverging from it breaks the entire system
4. **This has already caused problems** - manual edits were made and had to be reverted (see above)
5. **There is NO valid reason** to edit generated files directly - EVER
6. **The "quick fix" mentality is the problem** - it feels faster but creates more work

### NO EXCEPTIONS MEANS NO EXCEPTIONS

**"But I just need to add one method..."** → ❌ NO. Update codegen. (This exact rationalization caused the 2025-12-07 violation)

**"But it's faster to edit directly..."** → ❌ NO. The revert will waste more time. (Proven by 2025-12-07 violation)

**"But the codegen doesn't support this yet..."** → ❌ NO. Add support to codegen first.

**"But I'll update codegen right after..."** → ❌ NO. Update codegen FIRST, then regenerate. (This exact rationalization caused the 2025-12-07 violation)

**"But the user needs this fix urgently..."** → ❌ NO. Explain the constraint and fix codegen.

**"But I already started editing..."** → ❌ STOP. Undo. Go to codegen. Do not continue.

**"But it's just fixing a typo/signature..."** → ❌ NO. Even small changes go through codegen.

### Psychological Safeguards

**Before ANY edit to src/webidl/, say out loud (or in your response):**

> "I am about to edit [filename]. Let me verify this is NOT a generated file."
> "Path check: [full path] - does it contain interfaces/, typedefs/, dictionaries/, callbacks/, enums/, or mixins/?"
> "Result: [SAFE TO EDIT / STOP - GENERATED FILE]"

**If you feel the urge to "just quickly fix" a generated file:**

1. STOP
2. Recognize this is the exact thought pattern that causes violations
3. Take a breath
4. Go to codegen instead
5. Thank yourself later when the fix actually persists

### Codegen Command

```bash
zig build codegen -- specs/idl/ specs/supplementary/ --dest-root src/webidl/
```

### Correct Workflow

1. Identify what change is needed in generated output
2. **VERIFY** the target file is in `src/webidl/codegen/` (NOT interfaces/, etc.)
3. Modify the codegen to produce the desired output
4. Run codegen to regenerate ALL files
5. Verify the generated files have the correct changes
6. Run tests to verify everything works
7. Commit codegen changes AND regenerated files together

### If You Violate This Rule

1. Your changes WILL be reverted (just like 2025-12-07)
2. You will need to redo the work correctly through codegen
3. Time will be wasted (yours and the user's)
4. This section will be updated with your violation as a historical example
5. The user will lose trust in your ability to follow rules

**REMEMBER: When in doubt, DO NOT EDIT. Ask first.**

**REMEMBER: The fastest way to make a change is the CORRECT way - through codegen.**

**REMEMBER: You have already violated this rule once. Do not do it again.**

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
- Impls can call their OWN internal methods, but must use interfaces for OTHER types (see Golden Rule #13)

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

**Critical: Inheritance Deinit Chain**

When implementing a subclass, the `deinit` function MUST call the parent's deinit through the **interface**, not the impl:

```zig
// src/webidl/impls/Element.zig
const interfaces = @import("interfaces");
const Node = interfaces.Node;  // Parent interface for deinit chain

pub fn deinit(instance: *runtime.Instance) void {
    // Clean up Element's own resources
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);
    
    // ✅ CORRECT: Call parent deinit through interface
    Node.deinit(instance);
}
```

```zig
// ❌ WRONG: Calling parent impl directly
const NodeImpl = @import("Node.zig");

pub fn deinit(instance: *runtime.Instance) void {
    // ...cleanup...
    NodeImpl.deinit(instance);  // ❌ WRONG - bypasses interface
}
```

**Note on init vs deinit:**
- `init` may call parent impl directly (for StateType comptime parameter)
- `deinit` MUST always call parent through interface
- Use `errdefer ParentInterface.deinit(instance)` in init functions

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
- **Inheritance chain cleanup requires going through interfaces to ensure proper resource cleanup**

**Inheritance Chains That Must Follow This Pattern:**
- EventTarget → Node → Element → HTMLElement → specific HTML elements
- EventTarget → Node → CharacterData → Text/Comment
- EventTarget → Node → Document
- Event → CustomEvent, ErrorEvent, ProgressEvent, MessageEvent, etc.

See epic `whatwg-jwgc` for the full list and refactoring plan.

### 15. **NEVER Import V8 Directly - Use Runtime Abstraction** ⭐⭐⭐

**All JavaScript engine access MUST go through `src/runtime/` abstractions. NEVER import `v8` directly in impl files.**

**Architecture:**
- `src/runtime/` provides engine-agnostic interfaces
- Impl files use `runtime.Context`, `runtime.Instance`, and related abstractions
- The runtime layer handles V8-specific details internally
- This allows future support for other JS engines (JavaScriptCore, SpiderMonkey)

**Correct Pattern:**
```zig
// src/webidl/impls/SomeInterface.zig
const runtime = @import("runtime");

pub fn someMethod(instance: *runtime.Instance, callback: runtime.Callback) !void {
    const ctx = instance.ctx;
    // Use runtime abstractions for JS engine operations
    try ctx.invokeCallback(callback, args);
}
```

**Wrong Pattern:**
```zig
// src/webidl/impls/SomeInterface.zig
const v8 = @import("v8");  // ❌ NEVER do this!

pub fn someMethod(instance: *runtime.Instance, callback: v8.JSValue) !void {
    // ❌ Direct V8 usage bypasses abstraction
    const isolate = v8.v8_Isolate_GetCurrent();
    // ...
}
```

**When You Encounter Violations:**
If you find code that imports `v8` directly in impl files:
1. ✅ Refactor to use `runtime` abstractions
2. ✅ If needed abstraction doesn't exist, add it to `src/runtime/`
3. ✅ Update the impl to use the new abstraction
4. ❌ NEVER leave direct V8 imports in impl files

**Why This Matters:**
- **Engine Independence**: Enables future support for JSC, SpiderMonkey, etc.
- **Testability**: Runtime abstractions can be mocked for unit tests
- **Encapsulation**: V8-specific quirks are isolated in runtime layer
- **Maintainability**: Engine upgrades only affect runtime layer, not all impls

**Allowed V8 Imports:**
- `src/runtime/engines/v8/*.zig` - V8 engine implementation files
- `tests/v8/*.zig` - V8-specific test files
- Build/tooling scripts

**Violations to Refactor:**
Run this to find violations:
```bash
rg "^const v8 = @import" src/webidl/impls/ --type zig
```

### 16. **NEVER Use Function::NewInstance() for Wrapping Zig Instances** ⭐⭐⭐ ABSOLUTE RULE ⭐⭐⭐

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   🛑🛑🛑 ABSOLUTE PROHIBITION - NO EXCEPTIONS - EVER 🛑🛑🛑                  ║
║                                                                              ║
║   This rule exists because it was VIOLATED REPEATEDLY, wasting HOURS        ║
║   of debugging time on a fundamentally wrong approach.                      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

**When wrapping existing Zig instances in V8 objects, ALWAYS use `InstanceTemplate()->NewInstance()`.**

**NEVER use `Function::NewInstance()` for this purpose.**

**Why This Rule Exists:**

Chromium/Blink wraps millions of C++ DOM objects using `InstanceTemplate()->NewInstance()` and their prototype chain works correctly. This is **empirical proof** that the API works.

**The Mistake That Was Made (REPEATEDLY):**
1. V8 documentation mentions `Function::NewInstance()` sets up prototype chains
2. Agent incorrectly concluded `InstanceTemplate()->NewInstance()` doesn't work
3. Agent implemented `Function::NewInstance()` with complex "wrapper mode" mechanism
4. Implementation caused segfaults and memory corruption
5. Agent was told to revert, then made the SAME mistake again
6. This cycle repeated multiple times, wasting hours

**The Truth:**
- Chromium uses `InstanceTemplate()->NewInstance()` - this is FACT
- If our prototype chain isn't working, the bug is in OUR code, not V8
- The issue is likely in template configuration, inheritance setup, or method registration
- NOT in the choice of `InstanceTemplate()->NewInstance()` vs `Function::NewInstance()`

**What To Do When Prototype Chain Doesn't Work:**

1. ✅ Investigate how we configure `FunctionTemplate`
2. ✅ Check if `FunctionTemplate::Inherit()` is called correctly
3. ✅ Verify methods are registered on `PrototypeTemplate()`
4. ✅ Compare our template setup with Chromium's
5. ❌ **NEVER** switch to `Function::NewInstance()` - this is NOT the solution

**Correct Pattern (What We Use):**
```zig
// Get InstanceTemplate from FunctionTemplate
const instance_template = v8.v8_FunctionTemplate_InstanceTemplate(template);

// Create object - this IS the correct V8 API
const v8_object = v8.v8_ObjectTemplate_NewInstance(instance_template, context);
```

**FORBIDDEN Pattern (NEVER DO THIS):**
```zig
// ❌ NEVER use Function::NewInstance() for wrapping existing instances
const func = v8.v8_FunctionTemplate_GetFunction(template, context);
const v8_object = v8.v8_Function_NewInstance(func, context, 0, null);  // ❌ WRONG
```

**If You Feel Tempted to Use Function::NewInstance():**

1. STOP
2. Re-read this rule
3. Remember: Chromium uses `InstanceTemplate()->NewInstance()` and it works
4. The bug is in OUR template configuration, not V8's API
5. Investigate template setup instead

**NO EXCEPTIONS. NO "JUST THIS ONCE." NO "BUT THE V8 DOCS SAY..."**

The Chromium codebase is the authoritative reference, not V8 documentation snippets taken out of context.

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

1. **Identify context** - Determine which spec you're implementing (from file path or task description)
2. **Read spec** - Load complete spec from `specs/whatwg/[spec-name]/` or relevant spec directory
3. **Understand full algorithm** - Read all steps with context, dependencies, and edge cases
4. **Check dependencies** - Find required specs in `src/`
5. **Handle missing dependencies** - Create temporary mocks if needed
6. **Write tests first** - Test all algorithm steps and edge cases
7. **Implement precisely** - Follow spec steps exactly, numbered comments
8. **Document** - Inline docs with spec references (do this BEFORE committing)
9. **Verify** - No leaks, all tests pass, pre-commit checks pass
10. **✅ COMMIT** - Implementation + tests + inline docs together (see Golden Rule #7)
11. **Update CHANGELOG.md** - Document what was added
12. **✅ COMMIT** - Commit changelog update
13. **Update FEATURE_CATALOG.md** if user-facing API
14. **✅ COMMIT** - Commit catalog update

**Remember:** Commit after EACH working step. Implementation + tests + docs = ONE commit. Changelog and catalog are separate commits.

### Workflow (Bug Fixes)

1. **Identify context** - Determine which spec has the bug
2. **Write failing test** that reproduces the bug
3. **Read spec** - Load relevant spec from `specs/whatwg/` to verify expected behavior
4. **Fix the bug** with minimal code change
5. **Document** - Add/update inline docs if needed
6. **Verify** all tests pass (including new test), pre-commit checks pass
7. **✅ COMMIT** - Fix + test + docs together with clear description
8. **Update** CHANGELOG.md if user-visible
9. **✅ COMMIT** - Commit changelog update

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
- **Importing V8 directly in impl files** (must use runtime abstractions - see Golden Rule #14)

---

## Dependencies

### Internal Dependencies (Within Monorepo)

Most WHATWG specs depend on other WHATWG specs implemented in this monorepo:

**Finding Internal Dependencies:**
1. **Check `src/` directory** - Each spec has its own subdirectory
2. **Import patterns** - `@import("url")`, `@import("infra")`, etc.

**Common Dependency Patterns:**
- Most specs depend on **Infra** (`src/infra/`) - strings, bytes, lists, ordered maps
- Specs with Web APIs depend on **WebIDL** (`src/webidl/`) - type system
- URL, Fetch, and others depend on each other

**If Dependency Not Implemented:**
1. **Create temporary mock** with clear markers
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

---

## When in Doubt

1. **ASK A CLARIFYING QUESTION** ⭐ - Don't assume, just ask (one question at a time)
2. **Have you committed recently?** ⭐⭐⭐ - If you have working changes, commit them NOW
3. **Creating files?** - Put generated docs/scripts in `tmp/` unless explicitly requested otherwise
4. **Identify context** - Which spec are you working on? (file path, imports)
5. **Read the WHATWG spec** - Load complete spec from `specs/whatwg/[spec-name]/`
6. **Read the complete section** - Context matters, never rely on fragments
7. **Check dependencies** - Find implementations in `src/`
8. **Look at existing tests** - See patterns in similar specs
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
- The system automatically detects which spec you're working on from file paths
- Check `src/` for related implementations

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

### Zig 0.15: ArrayList API Changes (Unmanaged by Default)

**Date**: 2025-12-12  
**Lesson**: In Zig 0.15, `std.ArrayList(T)` is now **unmanaged by default** - it no longer stores the allocator internally.

**Old Pattern (Pre-0.15) - NO LONGER WORKS:**
```zig
// ❌ WRONG - This no longer compiles in Zig 0.15
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();
try list.append('a');
```

**New Pattern (Zig 0.15+) - Unmanaged:**
```zig
// ✅ CORRECT - Initialize with empty struct, pass allocator to methods
var list: std.ArrayList(u8) = .{};
defer list.deinit(allocator);
try list.append(allocator, 'a');
try list.appendSlice(allocator, "hello");
const owned = try list.toOwnedSlice(allocator);
```

**Alternative - Use ArrayListUnmanaged explicitly:**
```zig
// ✅ ALSO CORRECT - Same thing, more explicit
var list: std.ArrayListUnmanaged(u8) = .{};
defer list.deinit(allocator);
try list.append(allocator, 'a');
```

**Key Differences:**
| Aspect | Old (Pre-0.15) | New (0.15+) |
|--------|----------------|-------------|
| Initialization | `.init(allocator)` | `.{}` or `= .{}` |
| Stores allocator | Yes | No |
| `deinit()` | `list.deinit()` | `list.deinit(allocator)` |
| `append()` | `list.append(item)` | `list.append(allocator, item)` |
| `toOwnedSlice()` | `list.toOwnedSlice()` | `list.toOwnedSlice(allocator)` |

**Why This Change:**
- Reduces struct size (no allocator pointer stored)
- More explicit about which operations need allocation
- Consistent with other unmanaged data structures
- The old managed version exists but is **deprecated**: `std.array_list.AlignedManaged`

**Codebase Migration:**
When fixing old code, replace:
```zig
// Old
var results = std.ArrayList(T).init(allocator);
defer results.deinit();
try results.append(item);

// New
var results: std.ArrayList(T) = .{};
defer results.deinit(allocator);
try results.append(allocator, item);
```

**Takeaway**: Always pass the allocator to ArrayList methods in Zig 0.15+. The allocator is no longer stored in the struct.

---

### Zig 0.15: std.io.getStdOut() Removed

**Date**: 2025-12-12  
**Lesson**: In Zig 0.15, `std.io.getStdOut()` and `std.io.getStdErr()` no longer exist. Use `std.fs.File.stdout()` instead.

**Old Pattern (Pre-0.15) - NO LONGER WORKS:**
```zig
// ❌ WRONG - This no longer compiles in Zig 0.15
std.io.getStdOut().writeAll("hello\n") catch {};
const stderr = std.io.getStdErr();
```

**New Pattern (Zig 0.15+):**
```zig
// ✅ CORRECT - Use std.fs.File static methods
const stdout = std.fs.File.stdout();
stdout.writeAll("hello\n") catch {};

const stderr = std.fs.File.stderr();
stderr.writeAll("error\n") catch {};

// For buffered writing
var buffer: [4096]u8 = undefined;
var stdout_writer = stdout.writer(&buffer);
try stdout_writer.interface.print("formatted: {d}\n", .{42});
```

**Takeaway**: Replace `std.io.getStdOut()` with `std.fs.File.stdout()` and `std.io.getStdErr()` with `std.fs.File.stderr()`.

---

### Zig 0.15: std.fmt.formatIntBuf Removed

**Date**: 2025-12-12  
**Lesson**: In Zig 0.15, `std.fmt.formatIntBuf` no longer exists. Use `std.fmt.bufPrint` instead.

**Old Pattern (Pre-0.15) - NO LONGER WORKS:**
```zig
// ❌ WRONG - This no longer compiles in Zig 0.15
var buf: [20]u8 = undefined;
const len = std.fmt.formatIntBuf(&buf, value, 10, .lower, .{});
const str = buf[0..len];
```

**New Pattern (Zig 0.15+):**
```zig
// ✅ CORRECT - Use std.fmt.bufPrint
var buf: [20]u8 = undefined;
const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
```

**Takeaway**: Replace `std.fmt.formatIntBuf` with `std.fmt.bufPrint` using format strings.

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

**WHATWG specs define the web.** Browser compatibility depends on correct implementations. Precision matters.

**Cross-spec dependencies matter.** Handle them correctly by checking `src/` for implementations or creating temporary mocks.

**Document what you learn.** Future agents (and humans) will thank you for expanding this file when you discover better approaches.

**Thank you for maintaining the high quality standards of this project!**
