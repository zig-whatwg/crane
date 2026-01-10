# Oneshot Skill - Quick Usage Guide

## When to Load

Load this skill when user explicitly requests complete, uninterrupted execution:

- ✅ User says "oneshot [task]"
- ✅ User says "oneshot the epic"
- ✅ User says "oneshot bd-42"
- ✅ User says "just do it all"
- ✅ User says "implement everything"

## When NOT to Load

- ❌ Normal task execution (use regular mode)
- ❌ Exploratory work or research
- ❌ Ambiguous requirements
- ❌ Interactive debugging
- ❌ User hasn't explicitly requested oneshot

## Key Behaviors

### DO (During Oneshot)

- ✅ Work silently without status updates
- ✅ Skip obstacles and retry later
- ✅ Make incremental commits (silently)
- ✅ Continue despite blockers
- ✅ Follow all other skill guidelines (zig, commit_workflow, etc.)
- ✅ Provide comprehensive summary only at the end

### DON'T (During Oneshot)

- ❌ Ask for confirmation between steps
- ❌ Provide progress updates
- ❌ Announce each commit
- ❌ Stop for blockers
- ❌ Write summaries until completely done
- ❌ Worry about token usage

## Execution Pattern

```
Load oneshot skill
    ↓
Silent execution (implement, test, commit)
    ↓
Comprehensive final summary
    ↓
Unload oneshot skill
```

## Summary Format

Final summary must include:
- ✅ Completed work (with commits)
- ⚠️ Incomplete work (with reasons, attempts, issues created)
- 🚫 Blockers encountered (with impact and resolution needed)
- 📊 Statistics (features, commits, tests, files, LOC)
- 💡 Recommendations for next steps

## Quick Commands

```bash
# Start (claim issue)
bd update <id> --status in_progress --json

# During (create discovered issues - silent)
bd create "Title" -t type -p priority --deps discovered-from:<parent> --json

# End (close or update)
bd close <id> --reason "Completed via oneshot" --json
# OR
bd update <id> --notes "Oneshot execution summary" --json
```

## Integration

**Works with all skills:**
- `zig` - Code quality and testing
- `commit_workflow` - Incremental commits
- `pre_commit_checks` - Format/build/test before commits
- `beads_workflow` - Issue tracking

**Disables interaction from:**
- `communication_protocol` - No clarifying questions during oneshot

## Philosophy

**"Execute completely, report once."**

- Complete execution without interruption
- High quality despite speed
- Single comprehensive summary at the end
- Resilient to obstacles and blockers
