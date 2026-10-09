# Testing: A queued-record test must collect without a task turn

**Date**: 2026-10-09
**Lesson**: A test of a MutationRecord still in its observer's record queue must collect and read it in the same task: any `await` runs the notify microtask, which delivers the record and empties the queue, so the "queued" case silently becomes the "delivered" case.

**Why**: "Queue a mutation record" queues a mutation observer microtask; the first microtask checkpoint - the end of the current script, or any `await` of a timer or promise - delivers every pending record to the callback. `takeRecords()` after that returns `[]`. A collection helper that awaits a task turn so that deferred teardown can run is exactly such a checkpoint.

**What Happened**: crane/ed-mutation-record-nodes-gc.html first collected with `await collect(t)` (TestUtils.gc() plus `step_timeout` turns) between the mutations and `mo.takeRecords()`. On the base runner its queued cases failed with "expected 2 but got 0" - not the dangling node the test was written to catch, but an empty queue: the no-op callback had already been handed the records. The delivered cases, which do await, failed as intended ("span" read as "i").

**Fix**: For a queued record, collect synchronously: `TestUtils.gc()` runs the collection and its teardown before it returns (the adapter's LowMemoryNotification processes second-pass callbacks synchronously), and churn to reissue freed slots runs in the same task. Only the delivered-record cases await a turn.

**Takeaway**: **Know which checkpoint your helper crosses: an `await` delivers queued mutation records, so a test of the queue must collect, churn and read without one.**
