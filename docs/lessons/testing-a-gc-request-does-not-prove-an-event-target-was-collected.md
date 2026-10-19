# Testing: A GC Request Does Not Prove an Event Target Was Collected

**Date**: 2026-10-18
**Lesson**: Check an object's native identity and generation before interpreting a removal-and-GC test as proof of collection.

**Why**: An event dispatch can still expose its target after a listener removes it from the tree and calls `TestUtils.gc()`. Removal and a GC request alone do not establish that the object died.

**What Happened**: A radio focus listener removed its target and requested GC. A new test expected the subsequent synthetic click to be suppressed, but Crane's existing weak generation guard still yielded the original live radio. The native identity and generation remained unchanged. Blink also clicks its detached candidate, which its strong reference keeps alive.

**Fix**: Keep the prescribed generation guard and assert one click on the still-live target, plus no crash or new native leak. Bracket the operation with a native identity/generation check. Label activation has the same focus-listener case. Do not add a connectedness check to force a no-click expectation: live detached objects remain valid event targets. Record that this scenario cannot exercise the weak guard's null branch, and keep the counted-reference follow-up explicit.

**Takeaway**: **Test observed liveness, not an assumption that removing a node and requesting GC collected it. A weak guard remains a teardown safety net, not a substitute for a browser's strong hold.**
