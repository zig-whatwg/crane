# Testing: What the process start makes is a fact of the suite, not of whoever made it first

**Date**: 2026-11-03
**Lesson**: A state check that lets "what the process start makes" appear once lets any test's own copy of the start pass as the start - so the digest must know, per suite, which start makes each such thing, and hold it everywhere else.

**Why**: The Crane test runner's digest has two kinds of field: `held` (equal after the test) and `start` (what the process start makes: it may appear once, from the runner's initial value). `runtime.standalone_runtime` was a `start` field in every suite. But only tests-v8's test start makes a standalone runtime for the process (tests/v8/test_process.zig `start`); in every other suite each test makes and ends its own. So a tests/html test that started one for itself and left it - copying test_process.start's `if none runs, initializeRuntime` - looked exactly like the process start, and passed.

**What Happened**: Lane onebin1's one-binary run, shuffled into one process (seed 0xb3cd3f66e1c25aed), found 8 tests-html tests ORDER-DEPENDENT, each passing alone and failing with `runtime.standalone_runtime: 1 -> 0` and `runtime.browsers: N -> N+1` (lane testfix3). Two files left a standalone runtime: rejected_promises_drop_test.zig and workers/worker_thread_test.zig. Every later test that made and ended its own (`initializeRuntime(testing.allocator)` ... `deinitializeRuntime()`, about 160 sites) replaced the leftover - orphaned, still a live BrowserScope, so counted as a Browser - and ended with none. The blame landed on the 8 innocent tests, never on the two leavers. And because "once" was judged against the runner's initial value, after a blamed test took the runtime away the next leaver's start passed again: N rose 0, 1, ... 7 through the run. The minimal set, in one index-order process: rejected_promises_drop's two tests, worker_thread's six, then wh2_document_language - wh2 ORDER-DEPENDENT at position 9 with exactly that shape (alone: pass pass); each test in a process of its own, all pass.

**Fix**:
1. build.zig `SuiteConfig.standalone_runtime`: `.per_test` (default) or `.process_start` (tests-v8), written into the generated suite.zig.
2. tests/test_runner/state.zig compares `runtime.standalone_runtime` as `held` in a per_test suite: the leaver fails alone, by the field's name (RED: a state-fixture case, "makes a standalone runtime and leaves it"; and the leavers' 8 tests each fail alone with `runtime.standalone_runtime: 0 -> 1`).
3. The two leavers make and end their own, as every tests/html test does.

**Takeaway**: **A `start` field is only as precise as who is allowed to start it: declare per suite which start makes each piece, and hold it everywhere else - or the first test that copies the start is taken for it, and the blame lands on every innocent test after.**
