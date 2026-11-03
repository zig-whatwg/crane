# Lessons: how to use and write one

Moved verbatim from AGENTS.md (2026-11-03), section "Record what you learn". The core keeps the rule as one line and points here.

When you learn something new or find a better way to do something, you **must**
record it. Add a lesson when you: discover a bug pattern that could recur, find
a better approach to a common task, learn from user feedback about correct
methodology, identify a systemic issue rather than a one-off, or establish a new
best practice.

A lesson is two things, committed with the work that taught it:

1. **A file**, `docs/lessons/<category>-<slug>.md`, in this shape:

   ```markdown
   # Category: Brief Lesson Title

   **Date**: YYYY-MM-DD
   **Lesson**: One-sentence summary.

   **Why**: The underlying issue.

   **What Happened**: Context, what went wrong, how it manifested.

   **Fix**: Step-by-step, with code if relevant.

   **Takeaway**: **Bold key insight** for future work.
   ```

2. **One line in [docs/lessons/README.md](docs/lessons/README.md)**, under its category:
   `- [Title](<file>.md) - <the takeaway>` (the README's links are relative).

Categories: Architecture, Spec Compliance, Codegen, Testing, Debugging, Workflow.

## Lessons index: using them

- **Starting a batch:** your brief names the lessons chosen for its work. Read
  those files before you design anything.
- **Stuck on a symptom:** grep `docs/lessons/` for it before theorising, and
  read your area's section of the index.
