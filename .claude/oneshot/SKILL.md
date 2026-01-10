---
name: oneshot
description: Enables complete, uninterrupted execution of tasks from start to finish without pausing
license: MIT
---

# Oneshot Skill

**Automatically loaded when:** User explicitly requests "oneshot [task]" execution

---

## 🚨 CRITICAL WARNING: Do Not Stop Prematurely 🚨

**THE #1 MISTAKE: Providing a summary before completing the full scope.**

**Before writing ANY summary, ask yourself:**
1. Did the user say "epics" (plural) or "epic" (singular)?
2. If plural, have I completed ALL of them?
3. Can I honestly say "I attempted everything in the original request"?

**If you cannot answer YES to all questions → DO NOT SUMMARIZE → KEEP WORKING**

**Remember:**
- "oneshot the epic" = complete 1 epic
- "oneshot the epics" = complete ALL epics
- "oneshot epics in priority order" = complete ALL epics in that order

**The user expects COMPLETE execution. Don't stop after one item if they asked for multiple.**

---

## Overview

The Oneshot skill enables complete, uninterrupted execution of any task (epic, feature, bug, task) from start to finish. When activated, the LLM works through the entire scope without pausing for confirmation, status updates, or intermediate reports.

**Core principle: Execute completely, report once.**

---

## What is a Oneshot?

A "oneshot" is a complete execution mode where the LLM:
- ✅ Works through ALL subtasks and dependencies without stopping
- ✅ Makes incremental commits following commit_workflow (silently)
- ✅ Skips blocked items and retries them later
- ✅ Follows all other loaded skills (zig, pre_commit_checks, etc.)
- ✅ Provides a comprehensive summary only at the very end
- ❌ Does NOT pause for confirmation between steps
- ❌ Does NOT provide progress updates during execution
- ❌ Does NOT ask "should I proceed with X next?"

## ⚠️ CRITICAL: Scope Completion Rules

**BEFORE providing a summary, the LLM MUST verify:**

1. **Parse the user's request carefully:**
   - "oneshot the epic" = oneshot ONE epic (singular)
   - "oneshot the epics" = oneshot ALL epics (plural)
   - "oneshot bd-42" = oneshot that specific issue
   - "oneshot epics in priority order" = oneshot ALL epics, ordered by priority

2. **Identify the complete scope:**
   - If user said "the epics" (plural), list ALL epics at the start
   - If user said "in priority order", sort them by priority
   - Track which items are in scope vs out of scope

3. **Completion checkpoint (mental checklist before summary):**
   ```
   ❓ Did I complete ALL items in the original scope?
   ❓ If user said "epics" (plural), did I do ALL of them?
   ❓ If user said "in priority order", did I respect that order?
   ❓ Are there any in-scope items I skipped without attempting?
   ❓ Have I genuinely exhausted all attempts on blocked items?
   ```

4. **Only provide summary if:**
   - ✅ ALL items in scope have been attempted (completed, skipped, or blocked)
   - ✅ ALL blocked items have been retried at least once
   - ✅ You can honestly say "I attempted everything the user asked for"

5. **If answer to any checkpoint is "no":**
   - 🚫 DO NOT provide a summary yet
   - ✅ Continue working on the next in-scope item
   - ✅ Only summarize when truly complete

**Example of WRONG behavior:**
```
User: "oneshot the epics in priority order"
LLM: [completes 1 of 5 epics, provides summary]
❌ WRONG - Only 20% complete, summary is premature
```

**Example of CORRECT behavior:**
```
User: "oneshot the epics in priority order"
LLM: [silently works through all 5 epics]
LLM: [only provides summary after attempting all 5]
✅ CORRECT - Completed full scope before summary
```

---

## Trigger

User says:
```
oneshot the epic
oneshot bd-42
oneshot "implement the JSON parser"
oneshot this feature
```

---

## Execution Protocol

### Phase 1: Silent Preparation

**Before starting execution (silent - no announcements):**

1. **Parse user request and identify COMPLETE scope:**
   - Read the user's command word-by-word
   - Identify if singular ("the epic") or plural ("the epics")
   - List ALL items in scope (e.g., if "the epics", list epic-1, epic-2, epic-3, epic-4, epic-5)
   - Store this list mentally - this is the completion criteria
   - If "in priority order", sort the list by priority

2. **Load required skills** based on task type:
   - Code tasks → Load `zig` skill
   - Always load `commit_workflow` and `pre_commit_checks`
   - `beads_workflow` already loaded for issue tracking
   - `communication_protocol` always active

3. **Claim the first issue:**
   ```bash
   bd update <issue-id> --status in_progress --json
   ```

4. **Analyze complete scope:**
   - Identify all subtasks/dependencies for ALL in-scope items
   - Create mental execution plan across entire scope
   - Identify potential blockers
   - Estimate: "I need to complete [N] items total before summarizing"

5. **Begin execution** (no announcement)

### Phase 2: Silent Execution

**During execution (no status updates):**

1. **Work through tasks systematically:**
   - Implement each feature/subtask completely
   - Follow all loaded skill guidelines (zig, commit_workflow, etc.)
   - Make incremental commits after each logical unit
   - Run pre-commit checks before each commit

2. **Handle obstacles:**
   - If stuck on something, make reasonable attempts to resolve
   - If still stuck after multiple attempts, skip it
   - Track skipped items mentally for retry later
   - Continue with next available work

3. **Retry skipped items:**
   - After completing other work, revisit skipped items
   - Make additional attempts with fresh context
   - If still blocked, note for final summary

4. **Commit workflow:**
   - Make small, focused commits per commit_workflow skill
   - Each commit should be revertable if needed
   - Run format/build/test checks before each commit
   - No commit announcements during execution

5. **Dependencies and blockers:**
   - If encountering a dependency that can't be resolved, note it
   - Don't stop execution - continue with unblocked work
   - Document blocker details for final summary

### Phase 3: Completion

**⚠️ CRITICAL: Run completion checkpoint BEFORE moving to Phase 3:**

```
Mental Checklist:
□ Did I identify the complete scope in Phase 1?
□ Have I worked through ALL items in that scope?
□ If user said "epics" (plural), did I complete ALL epics?
□ Are there any in-scope items I haven't attempted?
□ Have I retried all blocked items at least once?

If ANY checkbox is unchecked → GO BACK to Phase 2, continue execution
If ALL checkboxes checked → Proceed to Phase 3
```

**When all work in scope is complete or all attempts exhausted:**

1. **Update issue status for ALL in-scope items:**
   ```bash
   # For each item in scope:
   # If fully complete
   bd close <issue-id> --reason "Completed via oneshot" --json
   
   # If partially complete
   bd update <issue-id> --notes "Oneshot execution: [summary of state]" --json
   ```

2. **Create issues for incomplete items:**
   ```bash
   bd create "Incomplete: [description]" -t task -p 1 --deps discovered-from:<parent-id> --json
   ```

3. **Provide final summary** (see Summary Format below)
   - Summary should cover ALL items in original scope
   - Clearly state what percentage of scope was completed
   - If multiple epics: list each epic's completion status

4. **Unload oneshot skill:**
   ```
   ✓ Unloading skill: oneshot
   ```

---

## Summary Format

**⚠️ ONLY provide summary after completing ALL items in scope!**

**Provide comprehensive final summary in this format:**

```markdown
# Oneshot Execution Summary: [Task Title]

## Scope Analysis

**Original Request:** [Quote user's exact request]
**Identified Scope:** [List all items that were in scope]
**Items Attempted:** [X / Y items]
**Overall Completion:** [XX%]

## Completed Work

✅ **[Feature/Component 1]**
- [Specific accomplishment]
- [Specific accomplishment]
- Committed in: [commit hash or description]

✅ **[Feature/Component 2]**
- [Specific accomplishment]
- [Specific accomplishment]
- Committed in: [commit hash or description]

[... all completed items ...]

## Commits Made

- [commit hash]: [commit message]
- [commit hash]: [commit message]
[... all commits ...]

## Incomplete Work

⚠️ **[Item 1]** (Priority: [0-4])
- **Reason**: [Why incomplete - blocker, complexity, etc.]
- **Attempts**: [How many times tried]
- **Issue**: [bd-XXX if created]
- **Next steps**: [What needs to happen to complete]

⚠️ **[Item 2]** (Priority: [0-4])
- **Reason**: [Why incomplete]
- **Attempts**: [How many times tried]
- **Issue**: [bd-XXX if created]
- **Next steps**: [What needs to happen]

[... all incomplete items ...]

## Blockers Encountered

🚫 **[Blocker 1]**
- **Description**: [What the blocker is]
- **Impact**: [What it blocks]
- **Workaround**: [If any workaround was used]
- **Resolution needed**: [What's required to unblock]

[... all blockers ...]

## Statistics

- **Total features completed**: [N]
- **Total commits**: [N]
- **Tests added/updated**: [N]
- **Files modified**: [N]
- **Incomplete items**: [N]
- **Blockers**: [N]
- **Lines of code**: [+N/-N]

## Issue Status

- **Issue**: [bd-XXX]
- **Final status**: [closed/open/in_progress]
- **Completion**: [100% / X%]

## Recommendations

[Any recommendations for next steps, improvements, or follow-up work]
```

---

## Interaction Guidelines

### What Oneshot Does

✅ **Silent execution:**
- No "I'm now working on..." announcements
- No "Should I proceed with..." questions
- No progress percentages or status updates
- Only the final summary when complete

✅ **Resilient execution:**
- Skips obstacles and retries later
- Documents what couldn't be completed
- Doesn't stop for blockers - notes them instead

✅ **Skill integration:**
- Follows zig skill for code quality
- Follows commit_workflow for incremental commits
- Follows pre_commit_checks before each commit
- Uses beads_workflow for issue tracking

✅ **Complete scope:**
- Implements all subtasks
- Handles all dependencies that can be resolved
- Creates comprehensive tests
- Updates documentation
- Commits incrementally throughout

### What Oneshot Does NOT Do

❌ **No interruptions:**
- Doesn't ask for permission between steps
- Doesn't provide status updates during work
- Doesn't pause to explain what it's about to do

❌ **No premature summaries:**
- Doesn't write summary until ALL work is attempted
- Doesn't provide partial reports
- Doesn't announce each completed feature

❌ **No token concerns:**
- Doesn't worry about how many tokens used
- Doesn't stop because task is complex
- Doesn't give up easily on difficult problems

---

## Decision Tree

```
User says "oneshot [task]"
    ↓
Parse request carefully
    ↓
Identify COMPLETE scope (singular vs plural)
    ↓
List ALL items in scope mentally
    ↓
Load oneshot skill
    ↓
🔧 Announce: "Loading skill: oneshot"
    ↓
Load other required skills (zig, commit_workflow, etc.)
    ↓
Store scope list: [item-1, item-2, ..., item-N]
    ↓
BEGIN SILENT EXECUTION
    ↓
┌─────────────────────────────────┐
│ FOR EACH ITEM IN SCOPE LIST:    │
│                                  │
│ Claim item (bd update in_progress)│
│                                  │
│ For each subtask in item:        │
│   1. Implement feature           │
│   2. Write/update tests          │
│   3. Run pre-commit checks       │
│   4. Commit (silently)           │
│                                  │
│ If stuck:                        │
│   - Try multiple approaches      │
│   - Skip if still stuck          │
│   - Track for retry later        │
│                                  │
│ If blocked:                      │
│   - Note the blocker             │
│   - Continue with other work     │
│                                  │
│ Close/update item status         │
│                                  │
│ Move to NEXT ITEM in scope list  │
└─────────────────────────────────┘
    ↓
All items in scope attempted?
    ↓
NO → Continue execution loop
YES → Proceed ↓
    ↓
Retry all skipped items across ALL scope items
    ↓
Still stuck? Note as incomplete
    ↓
END SILENT EXECUTION
    ↓
⚠️ RUN COMPLETION CHECKPOINT ⚠️
    ↓
Did I complete ALL items in original scope?
    ↓
NO → GO BACK to execution loop
YES → Proceed ↓
    ↓
Create issues for incomplete items
    ↓
Provide comprehensive final summary (covering ALL scope items)
    ↓
✓ Unload skill: oneshot
```

---

## Example Scenarios

### Scenario 1: Oneshot a Feature

**User:**
```
oneshot bd-42
```

**LLM:**
```
🔧 Loading skill: oneshot
🔧 Loading skill: zig
```

[Silent execution for 5-30 minutes]

```
# Oneshot Execution Summary: Implement JSON Parser

## Completed Work

✅ **Core Parser**
- Implemented JSON.parse() method
- Added recursive value parsing
- Implemented string escaping/unescaping
- Committed in: "feat: implement JSON.parse() core parser"

✅ **Type Support**
- Added support for objects, arrays, strings, numbers, booleans, null
- Implemented proper type conversions
- Committed in: "feat: add complete JSON type support"

✅ **Error Handling**
- Added ParseError with descriptive messages
- Implemented position tracking for errors
- Committed in: "feat: add JSON parse error handling"

✅ **Tests**
- Added 47 test cases covering all JSON types
- Added edge case tests (empty objects, nested arrays, escape sequences)
- Committed in: "test: add comprehensive JSON parser tests"

✅ **Documentation**
- Added module-level documentation with examples
- Documented all public APIs
- Committed in: "docs: document JSON parser API"

## Commits Made

- abc1234: feat: implement JSON.parse() core parser
- def5678: feat: add complete JSON type support
- ghi9012: feat: add JSON parse error handling
- jkl3456: test: add comprehensive JSON parser tests
- mno7890: docs: document JSON parser API

## Incomplete Work

None - all planned work completed.

## Blockers Encountered

None

## Statistics

- **Total features completed**: 5
- **Total commits**: 5
- **Tests added**: 47
- **Files modified**: 3
- **Incomplete items**: 0
- **Blockers**: 0
- **Lines of code**: +892/-23

## Issue Status

- **Issue**: bd-42
- **Final status**: closed
- **Completion**: 100%

## Recommendations

Consider adding:
1. Performance benchmarks for large JSON files
2. Streaming parser for memory efficiency
3. Pretty-printing/serialization support (currently only parsing)

✓ Unloading skill: oneshot
```

### Scenario 2: Oneshot an Epic (Partial Completion)

**User:**
```
oneshot the console epic
```

**LLM:**
```
🔧 Loading skill: oneshot
🔧 Loading skill: zig
```

[Silent execution for 45-90 minutes]

```
# Oneshot Execution Summary: Implement WHATWG Console API

## Completed Work

✅ **Basic Logging Methods**
- Implemented log(), debug(), info(), warn(), error()
- All methods delegate to Logger operation
- Committed in: "feat: implement basic logging methods"

✅ **Assertion and Clearing**
- Implemented assert() with condition checking
- Implemented clear() for group stack and buffer
- Committed in: "feat: implement assert() and clear()"

✅ **Counting Operations**
- Implemented count() and countReset()
- Added label-based counter tracking
- Committed in: "feat: implement count() and countReset()"

✅ **Grouping Operations**
- Implemented group(), groupCollapsed(), groupEnd()
- Added group stack management
- Committed in: "feat: implement console grouping"

✅ **Timing Operations**
- Implemented time(), timeLog(), timeEnd()
- Added timer table with infra.Moment
- Committed in: "feat: implement console timing operations"

✅ **Abstract Operations**
- Implemented Logger operation (spec lines 278-293)
- Implemented Printer operation (spec lines 340-343)
- Committed in: "feat: implement Logger and Printer operations"

## Commits Made

- abc1234: feat: implement basic logging methods
- def5678: feat: implement assert() and clear()
- ghi9012: feat: implement count() and countReset()
- jkl3456: feat: implement console grouping
- mno7890: feat: implement console timing operations
- pqr1234: feat: implement Logger and Printer operations
- stu5678: test: add tests for all implemented console methods
- vwx9012: docs: document console API

## Incomplete Work

⚠️ **Formatter Operation** (Priority: 1)
- **Reason**: Complex recursive format specifier processing with edge cases
- **Attempts**: 4 attempts with different approaches
- **Issue**: bd-127 created with discovered-from:bd-42
- **Next steps**: Need to implement full %o/%O object formatting with circular reference detection

⚠️ **trace() Method** (Priority: 1)
- **Reason**: Blocked on stack trace capture implementation
- **Attempts**: 2 attempts
- **Issue**: bd-128 created with discovered-from:bd-42
- **Next steps**: Requires RuntimeInterface.captureStackTrace() implementation

⚠️ **table() Method** (Priority: 2)
- **Reason**: Complex tabular rendering algorithm, time intensive
- **Attempts**: 3 attempts
- **Issue**: bd-129 created with discovered-from:bd-42
- **Next steps**: Implement array iteration, key extraction, property filtering, ASCII table rendering

## Blockers Encountered

🚫 **RuntimeInterface Implementation**
- **Description**: Stack trace capture requires host environment integration
- **Impact**: Blocks trace() method completion
- **Workaround**: trace() falls back to simple logging without stack trace
- **Resolution needed**: Decide on runtime integration strategy (V8, JavaScriptCore, etc.)

## Statistics

- **Total features completed**: 13
- **Total commits**: 8
- **Tests added**: 67
- **Files modified**: 5
- **Incomplete items**: 3
- **Blockers**: 1
- **Lines of code**: +1847/-156

## Issue Status

- **Issue**: bd-42 (Console Epic)
- **Final status**: open
- **Completion**: ~75%

## Recommendations

1. **Formatter operation**: This is critical for format specifier support (%s, %d, %o, etc.). Should be next priority.
2. **Runtime integration**: Decide on strategy for stack trace capture before implementing trace()
3. **table() implementation**: Can be deferred to lower priority as it's less commonly used
4. **Performance testing**: Add benchmarks for message buffering and format processing

Next suggested command:
```
oneshot bd-127  # Complete Formatter operation
```

✓ Unloading skill: oneshot
```

---

## Token Budget Handling

**Important:** During oneshot execution, the LLM should:

✅ **Not worry about token usage:**
- Execute the complete scope regardless of tokens used
- Complex tasks may use significant tokens - this is expected
- Don't abort or pause due to token concerns

✅ **Be efficient but thorough:**
- Don't read unnecessary files
- Don't repeat work already done
- Do read all required context for quality implementation

✅ **Track token usage passively:**
- System will provide token usage reminders
- Use this information to prioritize work order
- If approaching limits, focus on highest priority items first

**Philosophy:** Oneshot values completion over conservation. The goal is to finish the task completely, not to minimize tokens.

---

## Integration with Other Skills

### With beads_workflow

```bash
# Claim issue at start
bd update bd-42 --status in_progress --json

# Create issues for discovered work (silently during execution)
bd create "Found edge case" -t bug -p 1 --deps discovered-from:bd-42 --json

# Update at end
bd close bd-42 --reason "Completed via oneshot" --json
# OR
bd update bd-42 --notes "Oneshot: 75% complete, see summary" --json
```

### With zig

- Follow all Zig best practices
- Write comprehensive tests
- Maintain memory safety
- Document all public APIs
- Format code before committing

### With commit_workflow

- Make incremental commits after each feature
- Use descriptive commit messages
- Commit tests with implementation
- Enable rollback if needed
- NO commit announcements during execution

### With pre_commit_checks

- Run before EVERY commit:
  - `zig fmt` for formatting
  - `zig build` for compilation
  - `zig build test` for tests
- Abort commit if checks fail
- Fix issues and retry

### With communication_protocol

- NOT used during oneshot execution
- Oneshot assumes requirements are clear
- If requirements truly ambiguous, note in summary
- Don't stop to ask clarifying questions

---

## Differences from Normal Mode

| Aspect | Normal Mode | Oneshot Mode |
|--------|-------------|--------------|
| **Status updates** | Frequent | None (only final summary) |
| **Confirmations** | Asks before major steps | Never asks |
| **Progress reports** | Regular | None until complete |
| **Obstacle handling** | Asks for help/guidance | Skip and retry later |
| **Commits** | Announced | Silent (logged in summary) |
| **Scope** | Task-by-task | Entire epic/feature |
| **Token concern** | Conservative | Thorough completion |
| **Summary** | After each task | One comprehensive final |

---

## When to Use Oneshot

### Good Use Cases

✅ **Well-defined epics:**
- Clear requirements
- Obvious scope
- Established patterns

✅ **Batch implementations:**
- Multiple similar features
- Repetitive tasks
- Known algorithms

✅ **Complete features:**
- "Implement JSON parser"
- "Add all console methods"
- "Complete test coverage"

✅ **User explicitly requests it:**
- "oneshot this"
- "just do it all"
- "implement everything"

### Poor Use Cases

❌ **Ambiguous requirements:**
- Unclear scope
- Needs design decisions
- Missing specifications

❌ **Exploratory work:**
- Research tasks
- Proof of concepts
- Experimental features

❌ **Interactive debugging:**
- Investigating issues
- Analyzing behavior
- Diagnosing problems

❌ **High-risk changes:**
- Major refactorings
- Breaking changes
- Architecture shifts

**When in doubt, use normal mode.** Oneshot is powerful but best reserved for clear, well-defined tasks.

---

## Quality Standards

Even in oneshot mode, maintain high standards:

✅ **Code quality:**
- Follow language idioms (Zig best practices)
- Handle errors properly
- Maintain memory safety
- Write clear, readable code

✅ **Test coverage:**
- Test all public APIs
- Test edge cases
- Test error conditions
- Ensure tests pass

✅ **Documentation:**
- Document all public APIs
- Include usage examples
- Note any limitations
- Explain complex logic

✅ **Commits:**
- Focused, logical commits
- Descriptive messages
- Incremental checkpoints
- Revertable units

**Never sacrifice quality for speed in oneshot mode.**

---

## Summary

**The oneshot skill enables:**
- ✅ Complete, uninterrupted task execution
- ✅ Silent operation with final comprehensive summary
- ✅ Resilient handling of obstacles and blockers
- ✅ Integration with all other skills
- ✅ Incremental commits throughout
- ✅ High-quality output despite speed

**Remember: Execute completely, report once.**

---

## Quick Reference

| When | Action |
|------|--------|
| **Start** | Load skills, claim issue, begin silent execution |
| **During** | Implement, test, commit (no announcements) |
| **Stuck** | Skip, continue, retry later |
| **Blocked** | Note blocker, continue with unblocked work |
| **Complete** | Update issue, create issues for incomplete, provide summary |
| **End** | Unload oneshot skill |

**Oneshot = Silent execution + Comprehensive final summary**
