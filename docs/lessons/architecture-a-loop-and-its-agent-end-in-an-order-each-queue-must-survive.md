# Architecture: A loop and its agent end in an order, and what each holds of the other must survive it

**Date**: 2026-10-05
**Lesson**: An event loop queues host microtasks in its agent's microtask queue, and the agent's end (`engine.destroyAgent`) still runs that queue - or, for a terminated agent, drops it unrun. Whichever of the two ends first, the other still holds something of it.

**Why**: `queueMicrotask` heap-allocates a record (the steps and their context) and hands it to the engine; only running it frees it. The engine's end runs two microtask checkpoints (protocol_agents.endAgent) - and V8 clears a terminating isolate's queue without running it (MicrotaskQueue::RunMicrotasks: `is_execution_terminating()` deletes the ring buffer). A loop that ended before its agent left records the agent's end ran into freed memory (their contexts were the loop's promise arena); one that ended after a terminated agent leaked every record it had queued.

**What Happened**: Workers 1B-ii (queue item 13) put dedicated workers on threads of their own, so `terminate()` really aborts a running worker - and a terminated worker's agent ends with termination pending. The window loop and the worker loop each had the record with no owner at the agent's end. Moving the window loop's end after its agent (the first idea) was wrong for another reason: a window Task's `drop` may release engine handles (rejected_promises' notification releases its promises), so dropped window tasks must run while the agent lives.

**Fix**:
1. Each loop links the records of the microtasks it queued; a record unlinks itself when it runs.
2. The worker loop ends AFTER its agent (WorkerThread: destroyAgent, then loop.deinit) - safe because its `queueTask` drops a closing worker's task at once, while the agent lives - and frees every record still linked: the agent dropped them.
3. The window loop ends BEFORE its agent and orphans what is still linked: an orphaned record frees itself when the agent runs it, and runs nothing.
4. A test per loop: queue, end in the real order, count the allocator.

**Takeaway**: **When a loop and an engine agent end, write down which ends first and what each still holds of the other - queued microtasks, task drops that touch the engine - then make each holder survive the order, rather than reordering until one case stops crashing.**
