# Test Prompt for Skill Autodiscovery

Use this prompt in a **completely new context** (new chat session) to verify that the LLM properly discovers and understands the available skills.

---

## Test Prompt

```
I'm working on the WHATWG specifications monorepo in Zig. Before we start, I need you to discover what skills are available and when to use them.

Please perform the following steps:

1. Scan the skills/ directory to find all available skills
2. Read the USAGE.md file for each skill to understand when it should be used
3. Create a summary table showing:
   - Skill name
   - When to use it (brief, from USAGE.md)
   - Auto-loaded or always active?

After creating the summary, answer these scenario questions to prove you understand when to use each skill:

SCENARIO 1: I'm about to implement URL parsing according to the WHATWG URL Standard. Which skills should be loaded?

SCENARIO 2: I just wrote a Zig function and want to make sure it follows best practices for memory management and has no leaks. Which skill should I consult?

SCENARIO 3: The URL spec algorithm says "Let segments be an empty list" and I need to use the Infra spec's list implementation. Which skill helps me find where Infra is implemented?

SCENARIO 4: I need to use the Fetch standard, but it's not implemented yet in src/. I want to create a temporary mock to unblock my work. Which skill should I use?

SCENARIO 5: The requirements for a feature are unclear - I don't know if I should implement just basic parsing or full validation. What should I do?

SCENARIO 6: I'm ready to commit my changes. What skill tells me the quality checks I need to run first?

SCENARIO 7: I want to track this work as a task. Which skill should I use and what tool does it recommend?
```

---

## Expected Behavior

The LLM should:

1. ✅ **Scan skills/ directory** - Use `ls -d skills/*/` or similar
2. ✅ **Read USAGE.md files** - Read each skills/*/USAGE.md file
3. ✅ **Create accurate summary** - Table showing all 9 skills with correct usage info
4. ✅ **Answer scenarios correctly**:
   - SCENARIO 1: `whatwg` (spec implementation) + `zig` (code quality)
   - SCENARIO 2: `zig` (memory management, testing, leaks)
   - SCENARIO 3: `monorepo_navigation` (finding dependencies)
   - SCENARIO 4: `dependency_mocking` (create temporary mocks)
   - SCENARIO 5: `communication_protocol` (ask clarifying questions)
   - SCENARIO 6: `pre_commit_checks` (format, build, test)
   - SCENARIO 7: `beads_workflow` (task tracking with bd)

---

## Success Criteria

✅ LLM discovers all 9 skills without being told they exist
✅ LLM correctly reads and understands USAGE.md for each skill
✅ LLM can determine which skill(s) to use for each scenario
✅ LLM understands context-aware loading (file paths trigger certain skills)
✅ LLM knows some skills are always active (communication_protocol)

---

## If Test Fails

If the LLM doesn't discover skills or misunderstands when to use them:

1. Check that AGENTS.md clearly instructs to scan skills/
2. Check that all USAGE.md files exist and are clear
3. Check that USAGE.md files have consistent structure
4. Consider adding more explicit instructions in AGENTS.md about autodiscovery

---

## Notes

- This test should work in a **fresh context** with no prior knowledge
- The LLM should proactively scan skills/ as instructed in AGENTS.md
- The test validates both discovery and understanding of skill usage
