# Testing: A warm `zig build test` total counts only the suites that ran

**Date**: 2026-11-11
**Lesson**: The `N/M tests passed` of a `zig build test` Build Summary is the sum over the suites whose run step executed in THAT invocation. A suite whose run step was cached contributes nothing. Two gate runs of one branch can therefore print totals a thousand apart with every test passing in both, and a total that went down is not a test that stopped running.

**Why**: Each suite runs through `tools/test_launcher` as a build step, and `zig build test` seeds it from the executable's bytes so that an unchanged suite is skipped by Zig's cache (tests/AGENTS.md, "Seeds"). The summary counts what steps reported; a cached step reports no tests. How many suites are cached depends on what the change touched and on what the mirror built before, not on the branch.

**What Happened**: Lane nd2 batch 4 ran the PRE gate three times on server1 within three hours: `8548/8582 tests passed (34 skipped)` at a5453d48706, `8460/8487 (27 skipped)` at 1d5e6f55ca0 (one impl changed, 4 tests ADDED), `10500/10528 (28 skipped)` at the merged tip (style files changed, so the css suites ran too). The second looked like 99 tests lost by a commit that added four. The log said otherwise: 78 run/test steps `cached` (src-process, src-infra, src-url ...), 48 `test_launcher:` lines summing to PASS 8,368 FAIL 0, tests-html `PASS 2507`, no `error:` line; the third run had 76 cached steps and 50 launcher lines summing to PASS 10,408.

**Fix**:
1. Quote the Build Summary line as printed, and beside it the number of `test_launcher:` lines and their PASS / FAIL sums (`grep -a '^test_launcher: .*PASS [0-9]' tmp/gate/test.log`) and the count of `^error` lines. The gate is steps succeeded, FAIL 0 and no error line - never the total.
2. Before reading a lower total as a loss, count the cached steps (`grep -a -c -E '(run exe test_launcher|test) .* cached'`) and check that the suite holding the changed tests ran (its launcher line is there, with the new count).
3. To compare totals between two commits, run both cold (`-Dlaunch-seed=random` reruns every suite) or compare per-suite launcher lines.

**Takeaway**: **A warm test run's total is the suites that ran, not the suites that exist: report steps succeeded, the launcher lines' FAIL sum and the error-line count, and explain a moved total by the cached steps before anything else.**
