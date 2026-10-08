# Architecture: Task drop must relinquish dependent owners

**Date**: 2026-10-08
**Lesson**: A dropped completion task must clear the work that was waiting for it, including a preparation that has not yet joined its queue.

**Why**: Event-loop queue insertion can fail and invoke a task's drop callback synchronously. Releasing only the task payload leaves independent queue roots, render-blocking membership and load delays with no producer that can finish them.

**What Happened**: Ownership review of the docwrite module and render-blocking changes found module-graph cancellation released graph roots but left the prepared element active. Preparation subsequently enqueued it as fetching even when its initial task had already been dropped. Classic-fetch and queued-ready drops could also strand scheduled elements. These were source-level findings; allocator-backed delivery-drop tests were added before changing their cleanup.

**Fix**: Match the element and document generations to the exact preparation, unlink its queue entry, clear membership and load delay, and cancel producers before releasing the independent execution root. Unlink a producer before cancellation can re-enter it. Check that preparation still exists before scheduling after a potentially synchronous drop. During document destruction, cancel module clients while their dependent state remains usable. Never replace asynchronous delivery with synchronous script execution merely because allocation failed.

**Takeaway**: **A completion owner and the work awaiting completion are separate owners; dropping the former must resolve the latter's lifetime.**
