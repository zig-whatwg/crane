# Commit Workflow Skill

## Overview

This skill enforces best practices for git commit workflow in the WHATWG project.
The core principle: **commit after each completed feature, not at the end of a session**.

## The Golden Rule

**Every completed feature gets its own commit.**

A "feature" is any logical unit of work that can stand alone:
- A single console method implementation
- An abstract operation (Logger, Formatter, Printer)
- A TODO resolution (trace(), table())
- A documentation pass
- A refactoring or optimization
- A bug fix

## Commit Cadence Examples

### Example 1: Console Methods Implementation

```bash
# Completed assert() method
git add webidl/src/console/console.zig
git commit -m "feat: implement assert() with message prefixing

WHATWG Console Standard lines 52-72. Handles condition checking,
message concatenation, and owned string tracking."

# Completed clear() method
git add webidl/src/console/console.zig
git commit -m "feat: implement clear()

Empties group stack and message buffer per spec lines 75-80."

# Completed debug(), error(), info(), log(), warn()
git add webidl/src/console/console.zig
git commit -m "feat: implement basic logging methods

Implements debug(), error(), info(), log(), warn() per spec.
All delegate to Logger operation."
```

### Example 2: Abstract Operations

```bash
# Completed Logger
git add webidl/src/console/console.zig
git commit -m "feat: implement Logger abstract operation

Complete spec-compliant Logger per lines 278-293. Handles
format specifier detection and delegates to Formatter/Printer."

# Completed Formatter
git add webidl/src/console/console.zig
git commit -m "feat: implement Formatter abstract operation

Recursive format specifier processing per spec lines 297-338.
Supports %s, %d, %i, %f, %o, %O, %c with proper conversions."

# Completed Printer
git add webidl/src/console/console.zig
git commit -m "feat: implement Printer abstract operation

Message buffering with configurable output function.
Tracks owned strings for proper memory management."
```

### Example 3: Type System Changes

```bash
# Updated Console struct fields
git add webidl/src/console/console.zig
git commit -m "refactor: add message buffering and runtime integration

Add fields: message_buffer, print_fn, runtime, label_pool.
Change timer_table from i64 to infra.Moment (spec-compliant)."

# Updated types.zig
git add webidl/src/console/types.zig
git commit -m "feat: implement supporting types

Add Group, Message, CircularMessageBuffer, RuntimeInterface,
VTable, StackFrame per spec requirements."

# Updated format.zig
git add webidl/src/console/format.zig
git commit -m "feat: implement format specifier parsing

Add FormatSpec enum, SpecifierMatch struct, findAllSpecifiers()
for format string processing."
```

### Example 4: TODO Resolutions

```bash
# Completed trace()
git add webidl/src/console/console.zig
git commit -m "feat: complete trace() with stack capture

Implement stack trace capture using RuntimeInterface per
spec lines 109-117. Falls back to simple logging without runtime."

# Completed table()
git add webidl/src/console/console.zig
git commit -m "feat: complete table() with tabular rendering

Full table construction algorithm: array parsing, key extraction,
property filtering, ASCII rendering with borders. Spec lines 102-106."
```

### Example 5: Documentation

```bash
# Module-level docs
git add webidl/src/console/console.zig
git commit -m "docs: add comprehensive module documentation

140+ lines of docs: architecture, features, usage examples,
memory management, thread safety, performance notes."

# Type documentation
git add webidl/src/console/types.zig
git commit -m "docs: document supporting types

Complete documentation for Group, Message, CircularMessageBuffer,
LogLevel, StackFrame, RuntimeInterface, VTable with examples."

# Format documentation
git add webidl/src/console/format.zig
git commit -m "docs: document format specifier system

Add specifier table, escaping guide, browser compatibility notes,
performance characteristics, usage examples."
```

## Pre-Commit Checklist

Before every commit, verify:

1. ✅ **Tests pass**: `zig build test`
2. ✅ **Code formatted**: `zig fmt webidl/src/console/`
3. ✅ **Build succeeds**: `zig build`
4. ✅ **No TODOs** introduced without tracking
5. ✅ **Documentation added** for public APIs
6. ✅ **Commit message** is descriptive

## Commit Message Guidelines

### Structure

```
<type>: <short description (50 chars max)>

<optional body with context, reasoning, spec references>
<wrap at 72 characters>

<optional footer with references, breaking changes>
```

### Type Prefixes

- `feat:` - New feature implementation
- `fix:` - Bug fix
- `refactor:` - Code refactoring (no behavior change)
- `docs:` - Documentation only
- `test:` - Test additions/fixes
- `perf:` - Performance improvements
- `chore:` - Build, tools, dependencies
- `style:` - Code style changes (formatting, naming)

### Good Commit Messages

✅ **Excellent**:
```
feat: implement Formatter with recursive specifier processing

Complete implementation of Formatter abstract operation per WHATWG
Console Standard lines 297-338. Processes format specifiers (%s, %d,
%i, %f, %o, %O, %c) recursively until all are replaced.

Uses runtime conversions when available, falls back to simple string
conversion. Proper memory management with owned string tracking.
```

✅ **Good**:
```
fix: use infra.Moment for timer_table instead of i64

Spec lines 218-219 require timer table to map strings to "times",
not timestamps. Changed from i64 to infra.Moment for compliance.
```

✅ **Acceptable**:
```
docs: add usage examples to console.zig

Add 6 working examples covering basic usage, format specifiers,
timing, counting, grouping, and runtime integration.
```

### Bad Commit Messages

❌ **Too vague**:
```
update console
```

❌ **No context**:
```
fix stuff
```

❌ **Too broad**:
```
implement all console methods and add docs and fix types
```

❌ **Missing WHY**:
```
change timer_table type
```

## When NOT to Commit

Don't commit if:
- ❌ Tests are failing
- ❌ Code doesn't compile
- ❌ Code isn't formatted
- ❌ Work is incomplete (half-implemented feature)
- ❌ Contains debug code or commented-out experiments
- ❌ Breaking changes without documentation

## Handling Work in Progress

If you need to save partial work:

### Option 1: WIP Branch
```bash
git checkout -b wip/console-formatter
git add .
git commit -m "WIP: partial Formatter implementation"
# Continue work, squash/rebase before merging
```

### Option 2: Stash
```bash
git stash save "WIP: Formatter recursion logic"
# Switch tasks
git stash pop  # Resume later
```

### Option 3: WIP Commit + Amend
```bash
git commit -m "WIP: Formatter implementation"
# Continue work
git add .
git commit --amend  # Update the WIP commit
```

## Multi-File Changes

When a feature spans multiple files, include all in one commit:

```bash
# Feature requires changes to 3 files
git add webidl/src/console/console.zig
git add webidl/src/console/types.zig
git add webidl/src/console/format.zig
git commit -m "feat: add format specifier support

Implement complete format specifier pipeline:
- console.zig: Formatter and convertForSpecifier
- types.zig: Add RuntimeInterface for conversions
- format.zig: Add FormatSpec and findAllSpecifiers

Supports %s, %d, %i, %f, %o, %O, %c per spec lines 344-351."
```

## Reviewing Commits Before Push

Before pushing:

```bash
# Review commits
git log --oneline -10

# Check for:
# - Each commit is focused on one feature
# - Commit messages are descriptive
# - No "WIP" or "fix" chains (squash if needed)

# If needed, interactive rebase to clean up
git rebase -i HEAD~5
```

## Integration with Development Flow

### Typical Session Flow

```
1. Start task
   ↓
2. Implement feature
   ↓
3. Write/update tests
   ↓
4. Run tests (zig build test)
   ↓
5. Format code (zig fmt)
   ↓
6. ✅ COMMIT <-- Do this NOW
   ↓
7. Next feature
```

### NOT This:

```
1. Start task
   ↓
2. Implement feature 1
   ↓
3. Implement feature 2
   ↓
4. Implement feature 3
   ↓
5. Add docs
   ↓
6. Fix types
   ↓
7. Giant commit at end ❌
```

## Why Commit After Each Feature?

### Benefits

1. **Better History**
   - Easy to understand what changed when
   - Easy to find when bugs were introduced (git bisect)
   - Easy to revert specific features

2. **Better Collaboration**
   - Teammates can pull incremental updates
   - Code review is easier (small, focused changes)
   - Less merge conflicts

3. **Better Development**
   - Forces you to think in features
   - Clear progress markers
   - Safe checkpoints to return to

4. **Better Debugging**
   - Isolate when problems were introduced
   - Smaller surface area per change
   - Easier to reason about

### Real-World Example

Imagine you implement 10 features in one commit, then discover a bug.
Which feature introduced it? You'd have to review all 10 changes.

With incremental commits, you can:
```bash
git bisect start
git bisect bad HEAD
git bisect good HEAD~10
# Git automatically finds the problematic commit
```

## Automation Support

### Git Aliases

Add to `~/.gitconfig`:

```ini
[alias]
    # Quick commit with tests
    ct = "!f() { zig build test && git commit -m \"$@\"; }; f"
    
    # Format + commit
    fc = "!f() { zig fmt . && git add -u && git commit -m \"$@\"; }; f"
    
    # Full pre-commit workflow
    safe-commit = "!f() { zig fmt . && zig build test && git commit -m \"$@\"; }; f"
```

Usage:
```bash
git safe-commit "feat: implement Logger operation"
```

### Pre-Commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Ensure tests pass before commit

echo "Running tests..."
zig build test || {
    echo "Tests failed. Commit aborted."
    exit 1
}

echo "Formatting code..."
zig fmt webidl/src/console/ || {
    echo "Formatting failed. Commit aborted."
    exit 1
}

echo "All checks passed. Proceeding with commit."
exit 0
```

## Summary

**The commit workflow skill ensures:**
- ✅ Incremental, focused commits
- ✅ Clear git history
- ✅ Easier debugging and review
- ✅ Better collaboration
- ✅ Safe checkpoints throughout development

**Remember: Commit after each feature, not at the end of the session.**
