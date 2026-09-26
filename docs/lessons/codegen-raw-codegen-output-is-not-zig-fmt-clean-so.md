# Codegen: Raw codegen output is not `zig fmt`-clean, so regeneration looks like a 1,419-file change

**Date**: 2026-09-21
**Lesson**: Running codegen and then `git status` shows ~1,419 modified files
under `src/webidl/` with no semantic change in any of them.

**Why**: the committed generated files were formatted; the generator's own
output is not. The diff is almost entirely whitespace:

    13,175 lines  trailing spaces on otherwise-blank lines
     3,896 x 2    `pub const x = .{};` re-emitted as `.{\n};`
       111        `type:` re-emitted as `@"type":` (redundant but legal)

**What Happened**: this buried a real 75-file callbacks change inside 1,419
files of noise, and made "did codegen change anything?" unanswerable by
inspection. It also makes AGENTS.md's advice to delete the generated dirs and
regenerate from scratch read as catastrophic when it is harmless.

**Fix**: `zig fmt src/webidl/` immediately after any `zig build codegen`, before
`git status`. The pre-commit `zig fmt src/ tests/ tools/` already covers it, but
by then the diff has already been read wrong. Only the `@"type"` lines are a
genuine generator difference.

**Takeaway**: **Format generated output before you diff it, or the diff is
unreadable and a real change hides in it.**
