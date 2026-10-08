# Testing: Check the harness's roots before asserting collection

**Date**: 2026-10-08
**Lesson**: A forced-GC test must both invoke the engine's collector and avoid retaining its own target through harness callbacks.

**Why**: Crane exposes TestUtils.gc(), not a global gc(). An optional typeof-gc guard can make every collection test pass without collecting. Conversely, WPT Test.step retains callbacks in t.steps, so a step_func handler closing over a WeakRef target keeps that target alive for the rest of the test.

**What Happened**: The document-write GC fixtures silently skipped collection. Replacing the guard with TestUtils.gc() made collection real. A new Navigation test then appeared to leak every info object because its step_func callbacks closed over them; inspection of testharness.js identified the test's strong references.

**Fix**: Call TestUtils.gc() directly, leave the WeakRef-creation job before checking collection, and use a plain callback with explicit error aggregation when a step_func would retain the target. Verify retention fixtures with a temporary build that removes only the intended collector edge; preserve their failure as a negative control. Give cancellation tests a positive producer control without cancellation, and assert membership before testing its removal.

**Validation**: With only the parser’s array append removed, the detached-write and active-frame-removal fixtures each fail their sole subtest; the navigation fixture fails its detached-head subtest while its other six still pass. All three harnesses finish without crashes or ownership violations. The normal parser preserves all nine assertions.

**Takeaway**: **Prove that a lifetime test can fail for the ownership edge it claims to cover, and account for references held by the test itself.**
