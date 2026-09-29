# Architecture: A 0 ms timer armed in a task overtakes the tasks that task queued

**Date**: 2026-09-29
**Lesson**: In one turn of Crane's event loop, the timers run after the tasks that were queued before the turn began. A task queued during the turn waits for the next one. So a task that queues task A and then arms a 0 ms timer B sees B run first, in the same turn, and A only on the next turn.

**Why**: `browser/event_loop.zig` `runOnceBlocking` does step 2, then step 4. Step 2 (`runQueuedTasks`) runs only the tasks queued before the turn: a drain bounded by the queue length on entry, as HTML's event loop runs one task per iteration. Step 4 (`pollBlocking`) fires every timer that is due. A 0 ms timer armed during step 2 is due by step 4. A task queued during step 2 is not run until step 2 of the next turn.

**What Happened**: `<meta http-equiv=refresh content=0>` had to come due after the frame's document had completely loaded. "Completely finish loading" (`Document.completeLoading`) queues the container's load event as a task, the iframe load event steps. Arming the refresh timer right there would have fired the refresh, and its navigate event, before the iframe's load event. The test's `onload` handler installs the `onnavigate` that navigate-meta-refresh.html waits for, and that handler would not have run yet. All three browsers start the refresh wait once the load event has finished (Blink's `HttpRefreshScheduler::MaybeStartTimer` checks `LoadEventFinished`).

**Fix**: `completeLoading` queues a second lifecycle task, `.declarative_refresh`, behind the container's load event, and that task arms the timer. A document that has already completely loaded (a meta inserted later) arms the timer at once, because nothing is queued that the refresh must follow. `crane/nav-meta-refresh.html` pins the order: the first load event sees the refreshing document, the second sees the target.

**Takeaway**: **"Queue a task, then arm a 0 ms timer" runs the timer first. If a timer must follow a task you queued, arm it from a task queued behind that one.**
