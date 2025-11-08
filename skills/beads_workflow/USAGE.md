# Beads Workflow Skill Usage

## When to Use

**Load this skill for ALL task tracking.**

Automatically loaded when:
- Managing tasks and issues
- Tracking work progress
- Creating new issues
- Checking what to work on next
- Closing completed work

## What It Provides

1. **Complete bd (beads) workflow** - Create, claim, update, close
2. **Dependency tracking** - `discovered-from` links
3. **Auto-sync with git** - `.beads/issues.jsonl`
4. **JSON output** - Always use `--json` flag

## Core Commands

```bash
bd ready --json                    # Check ready work
bd create "Title" -t bug -p 1      # Create issue
bd update bd-N --status in_progress # Claim issue
bd close bd-N --reason "Done"      # Complete work
```

## Critical Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag
- ✅ Link discovered work with `discovered-from`
- ❌ NEVER use markdown TODO lists

## Full Documentation

See `SKILL.md` for complete workflow.
