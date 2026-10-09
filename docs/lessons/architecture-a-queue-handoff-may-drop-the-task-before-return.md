# Architecture: A queue handoff may drop the task before return

**Date**: 2026-10-07

**Lesson**: When a task queue owns a callback and its drop handler, a successful enqueue can end the task's lifetime before the enqueue call returns.

**Why**: A closing worker does not retain new tasks. Its `queueTask` calls `drop` immediately, and the drop handler may free the payload. A successful `queueDatabaseTask` therefore promises that ownership transferred, not that the payload remains alive for the caller's next statement.

**What Happened**: During a 10,035-file integration sweep, IndexedDB crashed in `IDBFactory.ConnectionTask.schedule` while a worker realm was being destroyed. The exact 41-file prefix crashed in five of six candidate runs and zero of six frozen-main runs. `ConnectionTask.schedule` wrote its queue handle and `queued` bit after `queueDatabaseTask` returned. The closing worker had already called `ConnectionTask.drop`, which destroyed the task.

**Fix**: Publish the queued state before calling the queue. On success, do not access the payload again; on error, the queue's contract guarantees it did not call either callback, so state can be restored. Unlink the task from its owner's pending list before destruction even when its realm has retired. Pin the synchronous-drop contract with a `std.testing.allocator` fake event loop, then check the observed crash with the same list and at least six repeats.

**Takeaway**: **After transferring task ownership, treat the payload as already destroyed.**

**Update (2026-10-09)**: the ConnectionTask fix missed IDBTransaction's `TransactionTask`, which had the same `schedule()` - and whose callers kept using the task after `schedule()` returned: `attachTransaction` stored it as the transaction's task, and `enqueueRequest`/`enqueueInternal` appended their work to its freed `pending` list. A worker that `Worker.terminate()` reached while its script was inside `db.transaction()` segfaulted writing `queued` into the freed block (the sweep crash journalled against WebCryptoAPI/algorithm-discards-context, lane wcrash); a worker that calls `close()` and then puts into a transaction that was waiting to start panics every run (crane/wc-idb-closing-worker-transaction.html). For a task that is scheduled again and again over its life, "never touch it after the handoff" reaches the callers too: each one does its work on the task - links it, appends to it - BEFORE calling `schedule()`, and takes the work back if the queue returns an error. **When you fix one user of a handoff, grep every other caller of the same queue for the same shape.**
