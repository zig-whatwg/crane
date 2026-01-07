# Commit Workflow Skill Usage

## When to Use

**Load this skill for ALL coding work.**

This skill ensures proper git workflow by requiring commits after each completed feature.

## Core Rule

**ALWAYS commit after completing a feature, bugfix, or milestone.**

## What Constitutes a "Feature"?

A feature is complete when:
- ✅ Implementation is finished
- ✅ Tests pass (`zig build test`)
- ✅ Code is formatted (`zig fmt`)
- ✅ Documentation is added (if public API)
- ✅ Build succeeds (`zig build`)

## When to Commit

Commit after:
1. ✅ **Each console method implemented** (e.g., `assert()`, `log()`, `count()`)
2. ✅ **Each abstract operation completed** (e.g., Logger, Formatter, Printer)
3. ✅ **Each TODO resolved** (e.g., trace() with stack capture, table() algorithm)
4. ✅ **Documentation passes added** (e.g., module docs, type docs, examples)
5. ✅ **Refactoring completed** (e.g., type fixes, optimization)
6. ✅ **Test suite additions** (e.g., new test files, coverage improvements)

## Commit Message Format

Follow the spec-compliant format:

```
<type>: <short description>

<optional longer description>
<optional reference to spec lines>
```

### Types:
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Code refactoring
- `docs` - Documentation only
- `test` - Test additions/fixes
- `perf` - Performance improvements
- `chore` - Build/tool changes

### Examples:

```
feat: implement Logger abstract operation

Complete implementation of Logger operation per WHATWG Console
Standard lines 278-293. Handles format specifier processing
and delegates to Formatter and Printer.
```

```
feat: add trace() with stack capture

Implements trace() with RuntimeInterface stack trace capture.
Falls back to simple logging when no runtime available.
Spec lines 109-117.
```

```
docs: add comprehensive console.zig documentation

140+ lines of module documentation including:
- Architecture overview
- 6 usage examples
- Memory management guide
- Performance optimizations
```

## Critical Rules

1. ❌ **NEVER make a giant commit** with multiple unrelated features
2. ✅ **ALWAYS commit incrementally** as features complete
3. ✅ **ALWAYS run tests** before committing
4. ✅ **ALWAYS format code** before committing
5. ✅ **ALWAYS write meaningful messages** explaining WHY, not just WHAT

## Anti-Patterns to Avoid

❌ **Bad**: Waiting until end of session to commit everything
❌ **Bad**: Committing with message "update console"
❌ **Bad**: Committing broken/untested code
❌ **Bad**: Skipping commits for "small changes"

✅ **Good**: Commit after each logical unit of work
✅ **Good**: Descriptive messages with context
✅ **Good**: All tests passing
✅ **Good**: Consistent commit cadence

## Workflow Integration

### After Completing a Feature:

```bash
# 1. Check status
git status

# 2. Run tests
zig build test

# 3. Format code
zig fmt webidl/src/console/

# 4. Stage changes
git add webidl/src/console/

# 5. Commit with descriptive message
git commit -m "feat: implement Formatter abstract operation

Complete recursive format specifier processing per spec lines 297-338.
Supports %s, %d, %i, %f, %o, %O, %c with proper type conversions."

# 6. Continue to next feature
```

## Why This Matters

**Benefits of incremental commits:**
- ✅ Better git history (easier to review, bisect, revert)
- ✅ Clearer progress tracking
- ✅ Easier code review
- ✅ Lower risk (smaller changes = easier to debug)
- ✅ Better collaboration (others can pull incremental updates)

**Risks of large commits:**
- ❌ Hard to review (too many changes at once)
- ❌ Hard to revert (can't undo one feature without undoing all)
- ❌ Hard to debug (which change caused the issue?)
- ❌ Lost context (can't remember why each change was made)

## Full Documentation

See `SKILL.md` for detailed workflow patterns and examples.
