# Architecture: "Cleanup complete" must not forget that cleanup happened

**Date**: 2026-09-25
**Lesson**: `instance_lifecycle.markCleanupComplete` REMOVED the instance's record. A node torn down by its tree keeps its wrapper-cache entry, and the cache skips an entry only while its instance reads `isCleanupStarted`. So the cache ran the node's deinit a second time.

**Why**: The record removal was meant for slab address reuse, but `Instance.init` already resets the flags of the address it hands out. During `removeContext` the cache is tearing down, so `markInstanceCleanedUp` cannot flag the entry either. The record was the only guard left.

**What Happened**: A sweep-only SEGV at 0x20 in `BrowsingContext.initChild` came down to a three-file replay (`HTMLElement-attachInternals`, `connected-callbacks-html-fragment-parsing`, then `cross-realm-callback-report-exception`), crashing in 25-50% of runs. The chain:
1. An iframe's deinit ran twice, so its `IFrameIntegration` block went onto the arena's free list twice.
2. The next page's Window state and a DocumentType were both handed that block.
3. Zeroing the DocumentType's state wiped the Window's `browsing_context`.

Three instruments, each one run, named it: BrowsingContext alloc/free with addresses (the parent read as `@0`, not a freed context); a watch list of live Window-state ranges checked on every arena push and pop (the block was popped a second time while live); and a stack on every push in the 512-byte class (both pushes were `HTMLIFrameElement.deinit`, on the same instance, in the same `removeContext`).

**Fix**: the record stays, marked complete. The cache frees such an instance's storage without a second deinit (`gc_integration.releaseStorage`), and the iframe nulls its state after freeing it. Pinned by `tests/runtime/instance_lifecycle_test.zig`. The replay: 25-50% crashes -> 0/12.

**Takeaway**: **A guard that forgets on completion guards nothing against a second caller. Forget on REUSE, where the allocator already knows the slot changed hands.**
