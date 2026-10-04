# Spec Compliance: Create an event before queuing its dispatch

**Date**: 2026-10-04
**Lesson**: When an algorithm creates an event before queuing its dispatch, the task must carry that event, not just enough data to construct it later.

**Why**: Event creation captures observable state, including timeStamp and the relevant realm. Dispatch can run much later, after another listener blocks or triggers collection.

**What Happened**: EventSource's first implementation queued owned message strings and constructed MessageEvent inside the dispatch task. Its data, origin and realm tests passed, but HTML 9.2.6 dispatch step 4 precedes step 8. A Crane test with a fully buffered data: response and a delayed first listener observed the second event's timestamp after the listener's barrier: construction had moved across the task boundary.

**Fix**: Create each MessageEvent when interpreting the completed event block, then queue its dispatch. Hold it using the existing engine.retainValue operation, and release that Owned exactly once when the task runs or is dropped. Release after the task's script returns. The probe also collects between dispatches, checking that the queued event remains alive.

**Takeaway**: **Preserve an algorithm's creation point as well as its dispatch point; deferred construction can change otherwise correct events.**
