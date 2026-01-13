# Temporary Files Skill - Usage Guide

## When to Use This Skill

**ALWAYS** - This skill is **always active** for this project.

Use this skill **every time** you are about to create any of the following:

## Triggers (When to Apply)

### Document Creation Triggers
- ✅ Creating a session summary
- ✅ Writing an analysis document
- ✅ Creating an implementation plan
- ✅ Generating debug output
- ✅ Creating investigation notes
- ✅ Writing any temporary markdown file
- ✅ Creating any AI-generated documentation

### Pre-File-Creation Checklist
Before creating ANY file, ask yourself:
1. Did the user explicitly request a different location? (rare)
2. Is this AI-generated content? (almost always YES)

**DEFAULT BEHAVIOR: If AI-generated → Use `tmp/` (unless explicitly requested otherwise)**

## Quick Decision Tree

```
About to create a file?
  ├─ Did user explicitly request a specific location?
  │  └─ YES → Use that location (root, history/, etc.)
  │
  ├─ Is it README/CHANGELOG/CONTRIBUTING/LICENSE update? 
  │  └─ YES → Project root (permanent docs)
  │
  └─ Otherwise (DEFAULT)
     └─ Use tmp/[category]/ (summaries, analysis, plans, debug, scratch)
```

**Key Principle:** `tmp/` is the DEFAULT for all AI-generated content unless user explicitly requests otherwise.

## Examples of When to Use

### Use Case 1: End of Session
**Trigger:** You completed work and want to summarize

**Action:** 
```bash
mkdir -p tmp/summaries
cat > tmp/summaries/session_2025-11-17.md << 'EOF'
# Session Summary
...
EOF
```

### Use Case 2: Investigating a Bug
**Trigger:** You're analyzing code or investigating an issue

**Action:**
```bash
mkdir -p tmp/analysis
cat > tmp/analysis/duplicate_warnings_investigation.md << 'EOF'
# Investigation: Duplicate Warnings
...
EOF
```

### Use Case 3: Planning Implementation
**Trigger:** You're designing a feature before implementing

**Action:**
```bash
mkdir -p tmp/plans
cat > tmp/plans/typedef_generation_design.md << 'EOF'
# Typedef Generation Design
...
EOF
```

### Use Case 4: Debug Output
**Trigger:** You ran tests or generated debug information

**Action:**
```bash
mkdir -p tmp/debug
./run_tests > tmp/debug/test_results_2025-11-17.txt
```

## When NOT to Use (Exceptions)

**Don't use tmp/ for:**
- ❌ README.md updates (permanent)
- ❌ CHANGELOG.md updates (permanent)
- ❌ CONTRIBUTING.md updates (permanent)
- ❌ LICENSE file (permanent)
- ❌ AGENTS.md updates (permanent)
- ❌ User explicitly requested permanent docs (ask first)

## Integration Points

**This skill works with:**
- `commit_workflow` - tmp/ is gitignored, never committed
- `beads_workflow` - Issue tracking separate from temporary files
- `communication_protocol` - Ask before writing to project root

## Skill Priority

**Priority Level:** CRITICAL - Always applies

This skill takes precedence over convenience. Even if it seems easier to write to project root, use `tmp/` instead.

## Common Mistakes to Avoid

❌ Writing session summaries to project root  
❌ Creating analysis docs in project root  
❌ Temporary markdown files anywhere except tmp/  
❌ Assuming user wants permanent docs without asking  

## Success Criteria

You're using this skill correctly when:
- ✅ All temporary files are in `tmp/`
- ✅ Project root only has permanent documentation
- ✅ `.gitignore` includes `/tmp/`
- ✅ You can safely `rm -rf tmp/` without losing project docs
