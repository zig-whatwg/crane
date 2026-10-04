# Spec Compliance: Clean up after dispatch in the same task

**Date**: 2026-10-04
**Lesson**: A post-dispatch step belongs in the dispatching task, even when a later task would usually run first.

**Why**: A listener can queue a timer or a new operation. Deferring the surrounding algorithm's cleanup to a separate task exposes stale state to those observers. Listener microtasks are different: HTML's callback checkpoint can run them before dispatch returns.

**What Happened**: IndexedDB cleared an open request's transaction association in the opening algorithm's next task. Five of six isolated completion/abort cases observed a non-null transaction from a timer, matching six upstream lifecycle failures. Reserving that next task earlier could mask the timing without implementing the specified step.

**Fix**: Associate the open request with its upgrade transaction through the owning hook and a temporary traced edge. After complete/abort dispatch returns, clear the association in that same task; abort also withdraws the intermediate result and returns the request to pending. Guard the saved request realm before dereferencing it. This follows IndexedDB ED 5.4 step 2.5.4 and 5.5 step 7.3, and WebKit's IDBTransaction::dispatchEvent. Keep both callback-microtask and later-task assertions.

**Takeaway**: **Task ordering cannot substitute for doing a step at its specified point.**
