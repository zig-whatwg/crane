# Testing: A hook in a function nothing calls has never compiled

**Date**: 2026-10-18
**Lesson**: Before relying on a hook point, check that its function has a caller - Zig analyses lazily, so a function nothing calls was never compiled, and a call placed in it is unverified however green the build is.

**Why**: `src/dom/mutation.zig`'s `move` (DOM "move", the algorithm `moveBefore` names) has no caller: `ParentNode.call_moveBefore` removes and inserts instead (a stated deviation). Lane domindex1 put its index hook into `move` beside the ones in insert and remove; every gate passed, because nothing ever analysed `move`.

**What Happened**: The integrator noticed that codex row 61 had found `move` unreachable. A Crane test calling `dom.mutation.move` directly, written to compile it, failed with two errors that had sat in the file unseen: `hasElementChild(new_parent)` against a two-parameter `hasElementChild`, and a call to `tree_helpers.getRoot`, which does not exist. Making `move` compile is the atomic-moveBefore item's work, so the test was dropped and the hook reported as never compiled; moveBefore reaches the index through the remove and insert hooks, which are compiled and tested (tests/dom/tree_ordered_map_test.zig, crane/domindex1-getelementbyid.html).

**Fix**: For each hook point, grep the function's callers. With none, either add a test that calls it (a compile check at least) or say in the report that the hook is uncompiled, and do not count it as covered.

**Takeaway**: **A green build says nothing about a function nobody calls: find a caller, or a test that calls it, before you count a change in it as done.**
