# Workflow: A worklist change is a code change - run the tests before committing it

**Date**: 2026-10-29
**Lesson**: Regenerating tests/wpt_0_1_worklist.txt with a new top-level directory breaks `zig build test` unless tests/wpt_runner/config.zig's in_scope_categories gains the same directory.

**Why**: The runner's test "the directory allowlist matches every directory in the generated worklist" compares the generated worklist with the allowlist in both directions. Without that, a suite reachable only through --from-file is never discovered by directory. It is the right check, but it lives in a Zig test, not in tools/wpt_subset.py.

**What Happened**: The integrator added web-animations/ for 0.1 (main 543df179906): the INCLUDE and EXCLUDE entries, then a regenerated worklist, then a commit and push. It ran no `zig build test`, on the reasoning that it was "docs and tools only". The next merge check failed that test in all six test executables that include the runner config, and so did every lane that had merged that main. The fix forward was one line (c18904fcb65).

**Fix**:
1. When wpt_subset.py adds a new top-level directory, add it to in_scope_categories in tests/wpt_runner/config.zig in the same commit.
2. Run `zig build test -Dspec=wpt_runner -Dtest-file=tests/wpt_runner/config.zig -j2` through the pool before pushing.

**Takeaway**: **A worklist change is a code change: the runner pins the worklist's directories in a test, so regenerate, add the directory to config.zig, and run that test before pushing.**
