# Beads Workflow Skill

**Automatically loaded when:** Managing tasks, tracking work, creating issues, checking what to work on

---

## ⚠️ CRITICAL: Use bd for ALL Task Tracking

**This project uses bd (beads) for ALL issue tracking.**

**NEVER use:**
- ❌ Markdown TODO lists
- ❌ Task lists in comments
- ❌ Manual tracking documents
- ❌ External issue trackers
- ❌ Any other tracking system

**ALWAYS use:**
- ✅ `bd` commands for all task management
- ✅ `--json` flag for programmatic use
- ✅ Dependency tracking with `discovered-from`
- ✅ Status updates and priority changes

---

## Why bd (beads)?

**bd is designed for modern development workflows:**

1. **Dependency-Aware**
   - Track blockers and relationships between issues
   - See what's ready to work on (`bd ready`)
   - Link discovered work to parent issues

2. **Git-Friendly**
   - Auto-syncs to `.beads/issues.jsonl` (5s debounce)
   - Version controlled with your code
   - Imports automatically after `git pull`

3. **Agent-Optimized**
   - JSON output for programmatic use
   - Ready work detection
   - Discovered-from links for traceability

4. **Prevents Confusion**
   - Single source of truth
   - No duplicate tracking systems
   - Clear workflow for all contributors

---

## Quick Reference

### Check for Ready Work

```bash
bd ready --json
```

**Shows:** Unblocked issues you can start working on

**Use when:**
- Starting a work session
- Looking for next task
- Checking project status

### Create New Issues

```bash
# Basic issue
bd create "Issue title" -t bug|feature|task -p 0-4 --json

# Issue with dependency link
bd create "Issue title" -p 1 --deps discovered-from:bd-123 --json
```

**Use when:**
- Planning new work
- Discovering bugs during implementation
- Breaking down large features

### Claim and Update

```bash
# Claim issue (mark in progress)
bd update bd-42 --status in_progress --json

# Change priority
bd update bd-42 --priority 1 --json

# Add notes
bd update bd-42 --notes "Found edge case in host parsing" --json
```

**Use when:**
- Starting work on an issue
- Issue priority changes
- Need to document progress

### Complete Work

```bash
bd close bd-42 --reason "Completed" --json
```

**Use when:**
- Work is done, tested, and committed
- Issue is no longer relevant
- Work is blocked permanently

---

## Issue Types

| Type | Description | When to Use |
|------|-------------|-------------|
| `bug` | Something broken | Code doesn't work as specified, memory leaks, crashes |
| `feature` | New functionality | New URL operations, new parsing features, new capabilities |
| `task` | Work item | Tests, documentation, refactoring, optimization |
| `epic` | Large feature with subtasks | Major features that need breakdown (e.g., "Implement JSON operations") |
| `chore` | Maintenance | Dependencies, tooling, build system, CI/CD |

**Examples:**
```bash
bd create "Fix memory leak in OrderedMap.set()" -t bug -p 0 --json
bd create "Implement forgiving base64 decode" -t feature -p 1 --json
bd create "Add tests for ASCII string operations" -t task -p 2 --json
bd create "Implement complete JSON parsing API" -t epic -p 1 --json
bd create "Update Zig to 0.15" -t chore -p 2 --json
```

---

## Priorities

| Priority | Level | When to Use |
|----------|-------|-------------|
| `0` | Critical | Security vulnerabilities, data loss, broken builds, spec violations |
| `1` | High | Major features, important bugs, blocking other work |
| `2` | Medium | Default priority, nice-to-have features, minor bugs |
| `3` | Low | Polish, optimization, code cleanup |
| `4` | Backlog | Future ideas, "would be nice" features |

**Examples:**
```bash
bd create "List append fails on empty list" -t bug -p 0 --json
bd create "Implement ordered set operations" -t feature -p 1 --json
bd create "Add more test coverage for edge cases" -t task -p 2 --json
bd create "Optimize character classification lookup table" -t task -p 3 --json
bd create "Support UTF-32 string conversions" -t feature -p 4 --json
```

---

## Workflow for AI Agents

### Step 1: Check Ready Work

**Before starting any work session:**

```bash
bd ready --json
```

**Output:**
```json
{
  "ready": [
    {
      "id": "bd-42",
      "title": "Implement ordered map operations",
      "type": "feature",
      "priority": 1,
      "status": "open"
    }
  ]
}
```

**Interpret:**
- If `ready` is empty → No unblocked work, check `bd list --json` for all issues
- If `ready` has items → Pick highest priority issue to work on

### Step 2: Claim Your Task

**When starting work:**

```bash
bd update bd-42 --status in_progress --json
```

**Why:**
- Signals to others you're working on it
- Prevents duplicate work
- Tracks work history

### Step 3: Work on It

**Standard development workflow:**

1. Read the WHATWG URL spec (`specs/url.md`)
2. Implement the feature/fix
3. Write tests (`tests/unit/`)
4. Run tests: `zig build test`
5. Format code: `zig fmt src/ tests/`
6. Update CHANGELOG.md
7. Commit changes

### Step 4: Discover New Work? Create Linked Issue

**If you find bugs, missing features, or technical debt during implementation:**

```bash
bd create "Found edge case: empty list behavior" -t bug -p 1 --deps discovered-from:bd-42 --json
```

**Why use `discovered-from`:**
- ✅ Traces where the issue was found
- ✅ Links related work together
- ✅ Helps understand issue context
- ✅ Prevents lost work items

**Common discovered work:**
```bash
# Found a bug while implementing a feature
bd create "OrderedMap doesn't handle duplicate keys correctly" -t bug -p 1 --deps discovered-from:bd-42 --json

# Discovered missing test coverage
bd create "Add tests for JSON nested objects" -t task -p 2 --deps discovered-from:bd-42 --json

# Found optimization opportunity
bd create "Optimize ASCII operations for UTF-8 strings" -t task -p 3 --deps discovered-from:bd-42 --json
```

### Step 5: Complete

**When work is done:**

```bash
bd close bd-42 --reason "Implemented ordered map operations with full test coverage" --json
```

**Verify before closing:**
- ✅ Code implemented and tested
- ✅ Tests pass (`zig build test`)
- ✅ Code formatted (`zig fmt --check`)
- ✅ CHANGELOG.md updated
- ✅ Changes committed to git

---

## Auto-Sync with Git

**bd automatically syncs with git:**

### Export (Automatic)

After any `bd` command that modifies issues:
1. bd waits 5 seconds (debounce)
2. Exports to `.beads/issues.jsonl`
3. You commit this file with your code

**No manual export needed!**

### Import (Automatic)

When `.beads/issues.jsonl` is newer than in-memory state:
1. bd detects the change
2. Imports issues from JSONL
3. Updates internal state

**Happens automatically after `git pull`!**

### What to Commit

```bash
# Always commit the JSONL file with your code
git add .beads/issues.jsonl
git add src/url.zig
git commit -m "Implement URL.parse() static method"
```

**Why commit JSONL:**
- ✅ Issue history is versioned
- ✅ Team sees same issue state
- ✅ Rollback code = rollback issues
- ✅ No synchronization issues

---

## MCP Server (Recommended)

**If using Claude Desktop or MCP-compatible clients:**

### Installation

```bash
pip install beads-mcp
```

### Configuration

Add to MCP config (e.g., `~/.config/claude/config.json`):

```json
{
  "mcpServers": {
    "beads": {
      "command": "beads-mcp",
      "args": []
    }
  }
}
```

### Usage

Instead of `bd` CLI commands, use MCP functions:

```
mcp__beads__list_ready_issues
mcp__beads__create_issue
mcp__beads__update_issue
mcp__beads__close_issue
```

**Benefit:** Direct integration with Claude, no shell commands needed

---

## Common Patterns

### Pattern 1: Start of Work Session

```bash
# 1. Pull latest issues
git pull

# 2. Check ready work
bd ready --json

# 3. Claim highest priority issue
bd update bd-42 --status in_progress --json

# 4. Read spec and implement
# ... (development work)

# 5. Close when done
bd close bd-42 --reason "Completed" --json
```

### Pattern 2: Discovered Bug During Implementation

```bash
# Working on bd-42 (feature)
# Found a bug in existing code

# 1. Create linked bug issue
bd create "URL parser crashes on null input" -t bug -p 0 --deps discovered-from:bd-42 --json

# 2. Decide priority:
#   - P0 (critical)? Fix immediately
#   - P1 (high)? Fix after current feature
#   - P2+ (medium/low)? Fix later

# 3. If fixing immediately:
bd update bd-50 --status in_progress --json
# ... fix the bug
bd close bd-50 --reason "Fixed null input handling" --json

# 4. Resume original feature work
bd update bd-42 --status in_progress --json
```

### Pattern 3: Breaking Down Large Feature

```bash
# 1. Create epic
bd create "Implement JSON parsing and serialization" -t epic -p 1 --json
# Returns: bd-100

# 2. Create subtasks
bd create "Implement JSON string parsing" -t task -p 1 --deps discovered-from:bd-100 --json
bd create "Implement JSON value conversion" -t task -p 1 --deps discovered-from:bd-100 --json
bd create "Implement JSON serialization" -t task -p 1 --deps discovered-from:bd-100 --json
bd create "Add JSON error handling" -t task -p 1 --deps discovered-from:bd-100 --json
# ... (more subtasks)

# 3. Work on subtasks in order
bd ready --json  # Check which are unblocked
bd update bd-101 --status in_progress --json
# ... implement
bd close bd-101 --reason "Completed" --json

# 4. When all subtasks done, close epic
bd close bd-100 --reason "All JSON operations implemented" --json
```

### Pattern 4: End of Work Session (Work Incomplete)

```bash
# Still working on bd-42, but need to stop

# 1. Add progress notes
bd update bd-42 --notes "Implemented 70% of ordered map, need to handle key comparison edge cases" --json

# 2. Create issue for remaining work if needed
bd create "Handle string key comparison in OrderedMap" -t task -p 1 --deps discovered-from:bd-42 --json

# 3. Mark as open (no longer in progress)
bd update bd-42 --status open --json

# 4. Commit JSONL with notes
git add .beads/issues.jsonl
git commit -m "WIP: OrderedMap implementation"
```

---

## Important Rules

### ✅ DO

- **Use bd for ALL task tracking** - No exceptions
- **Always use `--json` flag** - For programmatic use by agents
- **Link discovered work** - Use `discovered-from` dependencies
- **Check `bd ready`** - Before asking "what should I work on?"
- **Commit JSONL with code** - Keep issues and code in sync
- **Update status** - Mark in_progress when starting, close when done
- **Set appropriate priority** - P0 critical, P1 high, P2 default, P3 low, P4 backlog
- **Store working notes in `docs/`** - Personal analysis, progress docs (gitignored)
- **Update CHANGELOG.md** - For user-facing changes only

### ❌ DON'T

- **Don't create markdown TODO lists** - Use bd instead
- **Don't use external issue trackers** - bd is the single source of truth
- **Don't duplicate tracking systems** - Causes confusion
- **Don't forget `--json` flag** - Makes parsing output difficult
- **Don't skip `discovered-from` links** - Loses context for issues
- **Don't commit without JSONL** - Issues and code get out of sync
- **Don't bypass bd workflow** - Undermines team coordination
- **Don't clutter root with working notes** - Use `docs/` directory instead
- **Don't commit working notes** - `docs/` is gitignored (local only)

---

## Documentation Strategy

### Where to Store What

**Track in beads** (for task management):
- ✅ Work items (bugs, features, tasks)
- ✅ Progress notes (`bd update --notes`)
- ✅ Discovered issues
- ✅ Dependencies and blockers

**Store in `docs/`** (gitignored working notes):
- ✅ Analysis documents (dependency analysis, gap analysis)
- ✅ Research notes (SIMD experiments, optimization attempts)
- ✅ Progress summaries (phase completion reports)
- ✅ Test results (memory leak test logs)
- ✅ Planning documents (optimization plans, migration plans)
- ✅ Personal notes and scratch work

**Commit to git root** (essential public docs):
- ✅ `README.md` - User documentation
- ✅ `CHANGELOG.md` - Version history (user-facing changes only)
- ✅ `CONTRIBUTING.md` - Contributor guide
- ✅ `AGENTS.md` - Agent instructions
- ✅ `FEATURE_CATALOG.md` - API reference
- ✅ `LICENSE` - License file

### Why This Matters

**Problem:** Cluttered repository with 30+ working note files in root
- Hard to find essential docs
- Git commits full of "update progress" noise
- Duplicate tracking (beads + markdown docs)

**Solution:** Clean separation of concerns
- **beads** = task tracking and progress
- **docs/** = working notes (gitignored, local only)
- **root** = essential public documentation

**Benefits:**
- ✅ Clean root directory (5 essential docs vs 30+ working notes)
- ✅ No git noise from progress updates
- ✅ Single source of truth (beads for tracking)
- ✅ Keep working notes without cluttering repo

### Workflow for AI Agents

**When working on a task:**

1. **Track the task in beads:**
   ```bash
   bd create "Optimize UTF-8 decoder" -t task -p 1 --json
   bd update bd-42 --status in_progress --json
   ```

2. **Create working notes in `docs/`:**
   ```bash
   # Create analysis document (gitignored)
   cat > docs/optimization/utf8_decoder_analysis.md <<EOF
   # UTF-8 Decoder Optimization Analysis
   
   ## Current Performance
   - Baseline: 1,064 MB/s (10KB buffers)
   
   ## Optimization Ideas
   1. Cache line prefetching
   2. Lookup tables
   3. Branch hints
   
   ## Results
   - After optimization: 1,465 MB/s (+37.7%)
   EOF
   ```

3. **Update progress in beads:**
   ```bash
   bd update bd-42 --notes "Implemented cache prefetching, +37.7% improvement" --json
   ```

4. **Update CHANGELOG.md** (only if user-facing):
   ```markdown
   ## [Unreleased]
   ### Performance
   - Improved UTF-8 decoder performance by 37.7% for medium buffers (10KB)
   ```

5. **Complete the task:**
   ```bash
   bd close bd-42 --reason "Completed optimization, +37.7% improvement" --json
   ```

6. **Commit only essential changes:**
   ```bash
   git add src/utf8/decoder.zig CHANGELOG.md .beads/issues.jsonl
   git commit -m "perf: optimize UTF-8 decoder with cache prefetching (+37.7%)"
   ```

**Note:** Working notes in `docs/` are NOT committed (gitignored). They're for your reference only.

### When to Use Each

| Information | Store In | Committed? | Why |
|-------------|----------|------------|-----|
| Bug report | beads | Yes (JSONL) | Task tracking |
| Feature request | beads | Yes (JSONL) | Task tracking |
| Progress notes | beads (`--notes`) | Yes (JSONL) | Task tracking |
| Optimization analysis | `docs/optimization/` | No (gitignored) | Working notes |
| Test results | `docs/testing/` | No (gitignored) | Working notes |
| Migration plan | `docs/migration/` | No (gitignored) | Working notes |
| Dependency analysis | `docs/analysis/` | No (gitignored) | Working notes |
| API changes | `CHANGELOG.md` | Yes | User documentation |
| Usage examples | `README.md` | Yes | User documentation |

---

## Troubleshooting

### bd Command Not Found

```bash
# Install bd
cargo install beads-cli

# Or check if in PATH
which bd
```

### Issues Not Syncing

```bash
# Check JSONL file exists
ls -la .beads/issues.jsonl

# Manual export (rarely needed)
bd export

# Manual import (after git pull)
bd import
```

### Duplicate Issues

```bash
# List all issues
bd list --json

# Close duplicate
bd close bd-42 --reason "Duplicate of bd-50" --json
```

### Lost Changes After Git Pull

```bash
# bd auto-imports from JSONL after pull
# If issues seem wrong, check JSONL:
cat .beads/issues.jsonl | jq .

# Force re-import
bd import
```

---

## Integration with Other Skills

### With whatwg_spec

```bash
# Before implementing, check spec
bd update bd-42 --status in_progress --json

# Read specs/url.md for algorithm
# Implement following spec exactly

# Close when done
bd close bd-42 --reason "Implemented per WHATWG URL spec §4.1" --json
```

### With testing_requirements

```bash
# Create issue for test coverage
bd create "Add tests for JSON nested objects" -t task -p 2 --json

# While testing, discover edge cases
bd create "JSON parser fails on deeply nested arrays" -t bug -p 1 --deps discovered-from:bd-42 --json
```

### With pre_commit_checks

```bash
# Before closing issue, ensure pre-commit passes
zig fmt src/ tests/
zig build
zig build test

# If all pass, close issue
bd close bd-42 --reason "Completed with passing tests" --json
```

---

## Quick Command Reference

| Task | Command |
|------|---------|
| **Check ready work** | `bd ready --json` |
| **List all issues** | `bd list --json` |
| **Create bug** | `bd create "Title" -t bug -p 0-4 --json` |
| **Create feature** | `bd create "Title" -t feature -p 0-4 --json` |
| **Create task** | `bd create "Title" -t task -p 0-4 --json` |
| **Link discovered work** | `bd create "Title" -p 1 --deps discovered-from:bd-N --json` |
| **Start work** | `bd update bd-N --status in_progress --json` |
| **Add notes** | `bd update bd-N --notes "Progress notes" --json` |
| **Change priority** | `bd update bd-N --priority 0-4 --json` |
| **Complete work** | `bd close bd-N --reason "Done" --json` |
| **Export to JSONL** | `bd export` (automatic after 5s) |
| **Import from JSONL** | `bd import` (automatic on load) |

---

## Summary

**bd (beads) is the single source of truth for task tracking in this project.**

**Key principles:**
1. ✅ Use bd for ALL task tracking
2. ✅ Always use `--json` flag
3. ✅ Link discovered work with `discovered-from`
4. ✅ Check `bd ready` before starting work
5. ✅ Commit JSONL with code changes

**Workflow:**
1. `bd ready --json` → Check what's ready
2. `bd update bd-N --status in_progress --json` → Claim issue
3. Implement, test, document
4. `bd create "Found X" --deps discovered-from:bd-N --json` → Track new work
5. `bd close bd-N --reason "Done" --json` → Complete

**Result:** Clear, trackable, version-controlled task management that works seamlessly with git and AI agents.

For more details, see README.md and QUICKSTART.md in the beads repository.
