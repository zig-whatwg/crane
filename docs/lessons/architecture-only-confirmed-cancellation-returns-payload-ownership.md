# Architecture: Only confirmed cancellation returns payload ownership

**Date**: 2026-10-04
**Lesson**: A source can free queued callback data only after the queue confirms that it removed the callback.

**Why**: Cancelling an operation and cancelling its queued callback are different transitions. Releasing JavaScript roots does not free the native callback payload. Freeing that payload while the callback can still run instead creates a use-after-free.

**What Happened**: IndexedDB's worker fallback queued native timer callbacks without drop callbacks. Source teardown released roots but left each queued ConnectionTask for its callback to destroy. A traced worker-only factory test leaked32allocations:10tasks,10origin copies,10name copies and2notification arrays. Its window-only counterpart leaked none. Standalone shutdown tests also leaked none, so the actual leaking upstream file remained necessary for the before/after comparison.

**Fix**: Keep the timer interface and id together inside the queue helper and expose only a task handle to sources. Follow runtime.TimerInterface.clearTimeout's contract: true means removal succeeded and returns payload ownership; false leaves ownership with the callback. Clear the handle at callback/drop entry, before reentrant work, and protect cancellation while releasing roots that can reenter teardown. Prove the saved interface's lifetime: WorkerHost.teardownRealm destroys the IDB owners while its timer remains available; a handle cannot be used after the host is freed. Test successful cancellation, failed cancellation and callback entry with std.testing.allocator, then compare the same leaking file and its context controls.

**Takeaway**: **Cancellation transfers ownership only when the queue confirms removal.**
