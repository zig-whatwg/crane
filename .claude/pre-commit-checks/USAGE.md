# Pre-Commit Checks Skill Usage

## When to Use

**Load this skill when preparing to commit code.**

Automatically loaded when:
- Ready to commit code
- Running pre-commit hooks
- Ensuring code quality before push
- Handling pre-commit failures

## What It Provides

1. **Pre-commit workflow** - Format → Build → Test
2. **Handling failures** - How to fix format/build/test issues
3. **Tool integration** - VS Code, Vim, Emacs
4. **Performance considerations** - Fast pre-commit checks

## Core Checks

1. ✅ Code formatting (`zig fmt --check`)
2. ✅ Build success (`zig build`)
3. ✅ Test success (`zig build test`)

## Critical Rule

**Never commit unformatted, broken, or untested code.**

## Full Documentation

See `SKILL.md` for integration patterns.
