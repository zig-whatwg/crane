# Workflow: A new worklist directory joins the runner's directory allowlist too

**Date**: 2026-11-22
**Lesson**: When tools/wpt_subset.py's INCLUDE gains a new top-level WPT directory, add it to tests/wpt_runner/config.zig `in_scope_categories` in the same commit.

**Why**: `--from-file` sweeps bypass the runner's own scope, so a directory missing from the allowlist still runs in every A/B and sweep - only `wpt_runner <dir>/` reports "No tests found". config.zig's test "the directory allowlist matches every directory in the generated worklist" catches it, but only inside a full `zig build test`.

**What Happened**: Lane tpw added page-visibility/ and screen-orientation/ to the worklist (eb4a3cd8d). Two full A/Bs ran them fine; the gate's `zig build test` then failed with "worklist directory not allowed: page-visibility" (fixed in 91db373c5).

**Fix**: Add `.{ .name = "<dir>", .description = "..." }` to `in_scope_categories` beside the INCLUDE row, and regenerate the worklist with the tool.

**Takeaway**: **A worklist change that adds a directory touches two files: wpt_subset.py's INCLUDE and config.zig's in_scope_categories.**
