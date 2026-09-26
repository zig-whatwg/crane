# Architecture: A task fired into a worker from outside must end the worker's turn

**Date**: 2026-09-24
**Lesson**: Worker isolates share the page's thread and its timer. A callback that runs worker script from outside the worker's own timer trampoline (AbortSignal.timeout()'s task, for instance) must do what that trampoline does afterwards, or everything the worker posts stays inside the worker.

**What Happened**: `dom/abort/timeout.any.js` passed in the window and timed out in the worker. The timer fired and the `abort` handler ran. But the harness reports a worker's results by message, and those messages leave the worker only in `workerTimerTrampoline`'s epilogue: a microtask checkpoint, `DedicatedWorker.flushPendingMessages()`, and `scheduleMessageDispatch()`. Two traps along the way: the task must enter the signal's isolate (`v8_Isolate_Enter`), or V8 aborts with "Cannot create a handle without a HandleScope" on the page's isolate; and `std.debug.print` from that path never showed up in the runner's output, so a file written with `std.c.write` was what showed the task firing.

**Fix**: `worker_v8_context.finishTaskIn(isolate)` finds the worker by isolate (a threadlocal list of live contexts) and runs the epilogue. Call it at the end of any such task.

**Takeaway**: **In a worker, "the callback ran" is not "the page heard about it."** A worker's turn has an end, and every entry point into worker script has to reach it.
