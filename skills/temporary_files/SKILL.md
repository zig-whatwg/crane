# Temporary Files Management Skill

## Purpose

This skill defines the **mandatory policy** for all AI-generated temporary files, summaries, analyses, and documentation created during development sessions.

## Core Principle

**DEFAULT BEHAVIOR: ALL AI-generated files MUST go into `tmp/` directory by default.**

This is **non-negotiable** and applies to **every** file that is not explicitly part of the permanent project documentation.

**Exception:** ONLY when user explicitly requests a different location (root, specific directory, etc.).

---

## Directory Structure

```
tmp/                          # All temporary files (gitignored)
├── summaries/                # Session summaries, completion reports
├── analysis/                 # Investigation notes, code analysis
├── plans/                    # Implementation plans, design docs
├── debug/                    # Debug output, test results
└── scratch/                  # Any other temporary work
```

---

## What Goes in `tmp/` BY DEFAULT

### ✅ REQUIRED - Always use `tmp/` by default

**ALL of the following go to `tmp/` unless user explicitly requests otherwise:**

1. **Session Summaries**
   - `tmp/summaries/session_YYYY-MM-DD.md`
   - `tmp/summaries/epic_webidl-XXX_summary.md`
   - Implementation completion reports

2. **Analysis Documents**
   - `tmp/analysis/investigation_notes.md`
   - `tmp/analysis/codebase_analysis.md`
   - `tmp/analysis/duplicate_warnings_breakdown.md`

3. **Implementation Plans**
   - `tmp/plans/feature_implementation.md`
   - `tmp/plans/refactoring_plan.md`
   - `tmp/plans/architecture_design.md`

4. **Debug Output**
   - `tmp/debug/test_results.txt`
   - `tmp/debug/performance_report.md`
   - `tmp/debug/error_investigation.md`

5. **Scratch Work**
   - `tmp/scratch/quick_notes.md`
   - `tmp/scratch/todo_tracking.md`
   - Any other temporary work files

**This includes planning documents, summaries, analyses, investigation notes, debug output, and any temporary scripts.**

### ❌ NEVER use project root for these

**Project root is ONLY for permanent documentation:**
- `README.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `LICENSE`
- `AGENTS.md`
- Other explicitly permanent project docs

---

## Implementation Rules

### Rule 1: Default to `tmp/` First

Before creating ANY markdown file or document:

```zig
// Pseudo-logic - DEFAULT BEHAVIOR
if (user_explicitly_requested_different_location) {
    location = user_requested_location;  // Root, history/, etc.
} else {
    // DEFAULT for ALL AI-generated content
    location = "tmp/[category]/";
}
```

**Key principle:** Start with `tmp/` as the default. Only use a different location when user explicitly requests it.

### Rule 2: Use Descriptive Subdirectories

Organize by purpose:
- `tmp/summaries/` - Session and epic summaries
- `tmp/analysis/` - Investigation and analysis work
- `tmp/plans/` - Design and planning documents
- `tmp/debug/` - Debug output and test results
- `tmp/scratch/` - Everything else temporary

### Rule 3: Include Timestamps

For summaries and session files:
```
tmp/summaries/epic_webidl-fzj_complete_2025-11-17.md
tmp/analysis/duplicate_warnings_2025-11-17.md
tmp/debug/test_run_2025-11-17_14-30.txt
```

### Rule 4: Verify `.gitignore`

Ensure `tmp/` is gitignored:

```bash
# Check
grep -q "^/tmp/" .gitignore || echo "/tmp/" >> .gitignore

# Create directory
mkdir -p tmp/{summaries,analysis,plans,debug,scratch}
```

---

## Workflow

### Starting a Task

1. **Check if you'll create any documents**
   - Summaries? → `tmp/summaries/`
   - Analysis? → `tmp/analysis/`
   - Plans? → `tmp/plans/`

2. **Create directory structure**
   ```bash
   mkdir -p tmp/summaries tmp/analysis tmp/plans tmp/debug tmp/scratch
   ```

3. **Verify gitignore**
   ```bash
   grep -q "^/tmp/" .gitignore || echo "/tmp/" >> .gitignore
   ```

### During Work

**Every time you create a file, ask:**
- Is this permanent project documentation? → Project root (rare)
- Is this temporary/AI-generated? → `tmp/` (almost always)
- Is user explicitly requesting permanent location? → Confirm first

### Session End

Write session summary to:
```
tmp/summaries/session_YYYY-MM-DD_HH-MM.md
```

Include:
- What was accomplished
- Issues created/resolved
- Commits made
- Files generated
- Next steps

---

## Examples

### ✅ CORRECT Usage

**Session Summary:**
```bash
# Write to tmp/summaries/
cat > tmp/summaries/epic_webidl-fzj_complete_2025-11-17.md << 'EOF'
# Epic Implementation Complete

## Summary
...
EOF
```

**Analysis Document:**
```bash
# Write to tmp/analysis/
cat > tmp/analysis/duplicate_warnings_investigation.md << 'EOF'
# Duplicate Warnings Analysis

## Root Causes
...
EOF
```

**Implementation Plan:**
```bash
# Write to tmp/plans/
cat > tmp/plans/typedef_generation_design.md << 'EOF'
# Typedef Generation Design

## Approach
...
EOF
```

### ❌ WRONG Usage

**DON'T write to project root:**
```bash
# WRONG - temporary file in root
cat > EPIC_SUMMARY.md << 'EOF'
...
EOF

# WRONG - analysis in root
cat > DUPLICATE_WARNINGS_ANALYSIS.md << 'EOF'
...
EOF

# WRONG - implementation notes in root
cat > TYPEDEF_IMPLEMENTATION_NOTES.md << 'EOF'
...
EOF
```

---

## Exception: User Explicitly Requests Permanent Documentation

**Only write to project root when user explicitly says:**
- "Create a permanent reference document in the root"
- "Add this to the project documentation"
- "This should be committed and kept long-term"

**In those cases:**
1. Confirm the filename and location with user
2. Write to project root
3. Commit with the code changes

**Otherwise, default to `tmp/`**

---

## Benefits

### 1. Clean Repository
- No clutter in project root
- Clear separation: permanent vs temporary
- Easy to see what's part of the project

### 2. Safe Cleanup
```bash
# User can safely clean up at any time
rm -rf tmp/

# Or keep only recent work
find tmp/ -mtime +30 -delete
```

### 3. Version Control Clarity
- `tmp/` is gitignored
- Only intentional documentation gets committed
- No accidental commits of AI analysis

### 4. Organization
- Easy to find session summaries
- Investigation notes grouped together
- Clear workflow history

---

## Quick Reference

**Before creating ANY file:**

1. **Did user explicitly request a different location?** → Use that location
2. **Otherwise (DEFAULT)** → `tmp/[category]/`
3. **Not sure which category?** → Default to `tmp/scratch/`

**Directory mapping:**
- Session summaries → `tmp/summaries/`
- Investigation → `tmp/analysis/`
- Design docs → `tmp/plans/`
- Debug output → `tmp/debug/`
- Everything else → `tmp/scratch/`

**Always verify:**
```bash
# Ensure tmp/ exists and is gitignored
mkdir -p tmp/{summaries,analysis,plans,debug,scratch}
grep -q "^/tmp/" .gitignore || echo "/tmp/" >> .gitignore
```

---

## Skill Activation

This skill is **always active** for this project. Every time you start to create a document file, this skill should guide your decision.

**Mental checklist:**
- [ ] Is this a summary/analysis/plan/debug file?
- [ ] Have I created `tmp/` directory?
- [ ] Have I verified `.gitignore` includes `/tmp/`?
- [ ] Am I writing to the correct subdirectory?
- [ ] Would this clutter the project root?

If any answer suggests temporary storage, use `tmp/`.

---

## Integration with Other Skills

### With `commit_workflow` Skill
- Never commit files in `tmp/` (gitignored)
- Only commit permanent documentation
- Session summaries stay in `tmp/`

### With `beads_workflow` Skill
- Issue tracking is separate from temporary files
- `.beads/` is committed (permanent)
- `tmp/` is not committed (temporary)

### With `communication_protocol` Skill
- Ask clarifying questions BEFORE writing to project root
- Default to `tmp/` when unclear
- User can always request files be moved to permanent location later

---

## Common Patterns

### Pattern 1: Epic Completion Summary

```bash
# Create subdirectory
mkdir -p tmp/summaries

# Write summary
cat > tmp/summaries/epic_${EPIC_ID}_complete_$(date +%Y-%m-%d).md << 'EOF'
# Epic ${EPIC_ID} Complete

## Implemented
- Feature 1
- Feature 2

## Commits
- commit hash - description

## Files Changed
- file1
- file2

## Statistics
- X issues resolved
- Y files generated
EOF
```

### Pattern 2: Investigation Notes

```bash
# Create subdirectory
mkdir -p tmp/analysis

# Write analysis
cat > tmp/analysis/investigation_$(date +%Y-%m-%d_%H-%M).md << 'EOF'
# Investigation: Problem Description

## Findings
...

## Root Cause
...

## Recommendation
...
EOF
```

### Pattern 3: Implementation Plan

```bash
# Create subdirectory
mkdir -p tmp/plans

# Write plan
cat > tmp/plans/feature_name_design.md << 'EOF'
# Feature Name Implementation Plan

## Approach
...

## Tasks
...

## Timeline
...
EOF
```

---

## Troubleshooting

### Q: Where should session summaries go?
**A:** `tmp/summaries/session_YYYY-MM-DD.md`

### Q: Where should investigation notes go?
**A:** `tmp/analysis/investigation_topic.md`

### Q: Where should implementation plans go?
**A:** `tmp/plans/feature_plan.md`

### Q: What if user wants a permanent doc?
**A:** Ask for confirmation, then write to project root with their explicit approval.

### Q: What about CHANGELOG.md or README.md updates?
**A:** Those are permanent project docs - update them directly (not in tmp/).

### Q: Can I ever write to project root?
**A:** Yes, but ONLY for permanent documentation that user explicitly requests or that's part of the project's core docs (README, CHANGELOG, CONTRIBUTING, etc.).

---

**Remember: When in doubt, use `tmp/`. It's easier to move a file from `tmp/` to permanent location than to clean up the project root.**
