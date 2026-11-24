# Testing: Red-test a replacement allocator by committing its engine unwired

**Date**: 2026-11-23
**Lesson**: To show that tests of a new allocator fail on the old one, commit the new engine and the hooks the tests read (stats, a violation hook, task begin/end) BESIDE the old allocator, with the old allocator still serving every block - the tests then compile and fail at their assertions, which is the red run.

**Why**: Tests of hardening properties ("a double free is caught", "a freed block reads zero", "a node block is never reissued as an Event") need the new allocator's API to compile, so on the old tree they are a compile error, not a red result. A compile error proves nothing about the property.

**What Happened**: Lane hard1 (allocator hardening batch A) wrote twelve tests (tests/runtime/hard1_state_heap_test.zig) that drive the state arena and the slab through their existing API and read the span engine's stats and its `checks = .report` hook. The red commit (9a5d27f4b) held the engine and `BrowserScope.heapEngine` with the arena and slab still today's; server1 ran the file: 12 FAIL (every hardening test), 1 PASS (the configuration pin). The next commit made the arena and slab views of the engine, unchanged tests.

**Fix**:
1. Write the tests against the OLD allocator's call sites (arena.create/destroy, slab.alloc/free), reading the new engine only for what the old one cannot answer.
2. Commit the engine, its hooks and the tests, with the old allocator wired - keep a copy of the new wiring aside (tmp/).
3. Run the test file on the pool: each test must FAIL at an assertion, none crash or hang (bound every loop that waits on a counter the old code never moves).
4. Restore the wiring as the next commit; the same tests go green.

**Takeaway**: **Red means "compiles and fails at the property", so stage the new engine beside the old one and point the tests at the shared call sites.**
