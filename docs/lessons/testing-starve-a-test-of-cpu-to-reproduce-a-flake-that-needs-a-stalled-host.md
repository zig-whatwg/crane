# Testing: Starve a test of CPU to reproduce a flake that needs a stalled host

**Date**: 2026-11-20
**Lesson**: A test that fails only when the host takes real time away from it may not fail under ordinary load at all. On macOS, starve it instead: run the test and a few spinning shells at background QoS, which confines them all to the efficiency cores.

**Why**: tests/html/dm2_dying_figure_test.zig "a tree queued twice is counted once" asserted that a 2,101-node tree was freed after two `runEventLoopBlocking(20)` turns. Each turn is 20 ms of real time, and the deferred teardown runs its slices in a share of it. The test fails only when the thread loses most of those 40 ms, and its one failure (chat2, 2026-11-19) took 21.7 s against the usual 0.8-1.7 s. Busy cores alone do not do that: the scheduler still gives the test a core within a turn.

**What Happened**: main's binary passed 10/10 at rest and 50/50 beside four loops of its own test file (load 7-8 on chat2's 8 cores). With `taskpolicy -c background` on the test and on 8 `while :; do :; done` shells, the test competed for chat2's 4 E cores at low priority, and main's binary FAILED 5 of 5 (160-180 s a run). The fix, which turns until the slice queue is empty, PASSED 50 of 50 under the same starvation (11 s a run). The starvation stays on the E cores, so other jobs on the host keep the P cores.

**Fix**:
1. Reproduce with starvation: `taskpolicy -c background <launcher> <exe> --filter=...` beside N background-QoS spinners in the same job, and stop the spinners when the runs end.
2. Fix the test to wait on the condition it asserts (here: the deferred-teardown queue empty), with a deadline only as a failure guard.
3. Prove it under the same starvation, x50.

**Takeaway**: **Load is not starvation. To reproduce a test that fails when real time passes without it running, starve it (background QoS on the E cores) instead of loading the host, and prove the fix the same way.**
