# Architecture: A queue handoff may drop the task before return

**Date**: 2026-10-07

**Lesson**: When a task queue owns a callback and its drop handler, a successful enqueue can end the task's lifetime before the enqueue call returns.

**Why**: A closing worker does not retain new tasks. Its `queueTask` calls `drop` immediately, and the drop handler may free the payload. A successful `queueDatabaseTask` therefore promises that ownership transferred, not that the payload remains alive for the caller's next statement.

**What Happened**: During a 10,035-file integration sweep, IndexedDB crashed in `IDBFactory.ConnectionTask.schedule` while a worker realm was being destroyed. The exact 41-file prefix crashed in five of six candidate runs and zero of six frozen-main runs. `ConnectionTask.schedule` wrote its queue handle and `queued` bit after `queueDatabaseTask` returned. The closing worker had already called `ConnectionTask.drop`, which destroyed the task.

**Fix**: Publish the queued state before calling the queue. On success, do not access the payload again; on error, the queue's contract guarantees it did not call either callback, so state can be restored. Unlink the task from its owner's pending list before destruction even when its realm has retired. Pin the synchronous-drop contract with a `std.testing.allocator` fake event loop, then check the observed crash with the same list and at least six repeats.

**Takeaway**: **After transferring task ownership, treat the payload as already destroyed.**
