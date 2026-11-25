# Testing: A removal proven by the compiler still moves the tests' pins

**Date**: 2026-11-24
**Lesson**: "Dead code, proven by the build" means the code had no caller. It does not mean no test observes it: an exact size pin, a field-count check or a layout probe reads the type the removed field was in, so the proof of a dead-code removal is the build AND the test run.

**Why**: A struct field nothing reads can still be pinned by a test that measures the struct (`@sizeOf`, a field list, an offset). Compiling every test executable (`check-tests`) proves the pin's test compiles, but a size pin fails only when it RUNS.

**What Happened**: Lane core1's dead-code pass removed document_state.InternalState's stylesheet_tracker, a StylesheetBlockingTracker that no code ever fed (a19fd7a6f). It was proven by crane-check, check-tests and wpt-runner, with every lint at baseline. The lane's final Linux gate then failed tests/dom/nav2b7_document_state_size_test.zig: "Document's state is 1,680 bytes", 1,616 measured, "alone: fail fail". The 64 bytes were the removed tracker.

**Fix**:
1. A dead-code removal's proof includes `zig build test -j2` (or at least the suites of the modules whose types it changed), not only the compile steps.
2. Before removing a field, grep tests/ for `@sizeOf(` of its container and for pins of its layout. Update the pin in the same commit, and record the old size and why it moved.

**Takeaway**: **The compiler proves a removed thing had no caller; only the test run proves nothing measured it.**
