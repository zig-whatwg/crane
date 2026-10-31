# Workflow: Compare skip counts before comparing a test binary's cost

**Date**: 2026-10-30
**Lesson**: A test binary's RSS and time compare across toolchains only when both runs ran the same tests: the Zig 0.17 trial's "5 MB / 16 s -> 713 MB / 60 s" was three tests that skipped on one side.

**Why**: Some tests skip themselves when an input is missing - tests/wpt_runner's selection and manifest tests return `error.SkipZigTest` without `tests/wpt/MANIFEST.json`. A skipped test costs nothing, so a run on a checkout without the input looks cheap, and the comparison measures the checkout, not the toolchain.

**What Happened**: The trial's 0.16 run reported tests/wpt_runner's 104-test binary (`discovery`, which runs manifest.zig's and selection.zig's tests through its imports) as "101 pass, 3 skip, 5 MB, 16 s"; its 0.17 run as "104 pass, 713 MB, 60 s". The 0.16 mirror had no MANIFEST.json (its tests/wpt was crane/-only: workflow-a-crane-test-in-a-worktree-unshares-its-mirrors-wpt-tree.md); the 0.17 mirror had the full tree. Lane zig017mem ran the same binary on each toolchain, with the 40 MB manifest present and absent: 0.16 1,003 MB / 74.6 s and 5 MB / 5.6 s; 0.17 680 MB / 58.5 s and 4 MB / 5.9 s. The three tests load the whole manifest; 0.17 is the cheaper of the two.

**Fix**:
1. Read the pass/skip/fail counts of both runs before their RSS or time; when they differ, run the binary again with the same inputs on both sides.
2. To measure a test binary, run it directly (`/usr/bin/time -l <binary>` from the repo root, as the build's run step does) rather than reading one line of a build summary.

**Takeaway**: **A skipped test costs nothing: compare the skip counts before you compare the cost.**
