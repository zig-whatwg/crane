# Architecture: Record a wait before you start the work that ends it

**Date**: 2026-10-28
**Lesson**: A traversal item waits for the populations it starts, and each population reports its end by ids. That end can come inside the very call that starts the population: an immediate failure, or a fast path that commits synchronously. So the wait is recorded first, a population that reports "not started" counts as ended, and an item whose last wait ended inside its own run is finished once that run returns.

**Why**: The queue keeps the waits of the running item ("apply the history step" 12.8 and 14: lane nav2 C1). The population (HTMLIFrameElement's navigation record) reports from `destroy()`, which runs on every way a navigation ends. If the wait were recorded after `traverseNavigable` returned, an end reported inside the call would find nothing to remove. The wait recorded afterwards would then never end, and the traversable's queue would stall for good. If instead the queue completed an item whenever its wait set went empty, an end inside the run would complete the item while the run was still about to start the next navigable's population.

**What Happened**: Designing C1's waits. The about:blank and srcdoc populations the native tests use often commit inside `traverseNavigable`. A bfcache restore never starts one. A failure destroys the record before `navigate` returns. Each of those orders would either have stalled the queue or ended the item early.

**Fix**: `TraversalQueue.waitFor` (by traversable id and token) runs before `traverseNavigable(.., waiter)`. The hook returns whether the population is still in flight, and "false" is followed by `populationEnded`, which is idempotent. `stopWaiting` completes an item only when its run is not on the stack. The service completes one whose `uses_waits` set emptied inside the run. The item returns `.done` when it recorded no wait at all. Native cases cover an end inside the run, the last end, another token, a destroyed navigable and the traversable's end (tests/html/nav2_traversal_queue_test.zig).

**Takeaway**: **When work reports its end asynchronously, register the waiter before starting the work, treat "never started" as an end, and finish a waiter only when nothing more can be added to its wait set.**
