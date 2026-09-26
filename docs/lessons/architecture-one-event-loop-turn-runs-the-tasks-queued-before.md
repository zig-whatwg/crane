# Architecture: One event loop turn runs the tasks queued before it, and no more

**Date**: 2026-09-24
**Lesson**: `V8EventLoop.runOnceBlocking` drained its task queue until it was empty, so a task that queues a task never let the call return. The WPT runner checks the per-file deadline between calls, so its ceiling never fired.

**What Happened**: `beforeunload-canceling.html` ran into it. A frame's load handler sets `location.href = "about:blank"`. Crane keeps the frame's global across the navigation (a spec deviation: a new document gets a new Window), so the handler survives and the next load runs it again. The process hung until the supervisor's stall watchdog killed it at 150 s. The journal records that as TIMEOUT with `wall_ms` 0.

**Fix**: `runQueuedTasks` runs the tasks present when it starts. A task they queue waits for the next turn, which `runEventLoopBlocking` begins immediately (a non-empty queue polls without blocking). Pinned by `tests/v8/event_loop_turn_test.zig`.

**Takeaway**: **A drain loop's bound is the queue length on entry, never "until empty."** The second is a promise that nothing it runs will ever queue more.
