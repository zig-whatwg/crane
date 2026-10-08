# Architecture: A tree teardown must return unwrapped node storage

**Date**: 2026-10-08
**Lesson**: Cleaning a node's registries and NodeBase does not return its Instance or state storage when its wrapper's finalizer already left that storage to the tree.

**Why**: A parented node remains owned by its tree after the collector takes its wrapper. The wrapper's finalizer drops its cache entry without freeing the native node. When the detached root is collected later, its recursive teardown cleans the child, but only the root's finalizer returns storage. No finalizer remains to return a child whose entry already went.

**What Happened**: The persistent parser traced its nodes from the document so detached open elements survived across writes. A 10,000-cycle `document.open()` and incremental-write benchmark with forced collection then retained 38,099 Instances despite having only 13 NodeBase bridge entries and 12 wrapper-cache entries. The resources had been cleaned; the storage ownership had a gap. The identical baseline retained 16 Instances. After the fix, the matching benchmark retained 21 Instances and its live state growth fell from 40.3 MB to 0.0 MB (2 B/cycle). An extended 30,000-cycle run kept the general allocator at 72.5 MB across all six 5,000-cycle samples, with 21 live Instances and 0 B/cycle of live state growth at the end. Storage recycling does not imply that the allocator returns its batch capacity to the OS.

**Fix**: After the node owner's complete type-specific teardown, return storage for a completed, unwrapped node only when its captured live slab generation still matches and its saved realm still has an engine. Keep the existing storage owner for cached wrappers, retired realms and coordinated teardown. Never query a cache during its teardown: it can still contain keys whose entry values have already been destroyed. A later pending finalizer rejects the returned slot by generation. Tests must assert allocation counts and generations before runtime shutdown, because pool shutdown conceals retained storage from `std.testing.allocator`.

**Takeaway**: **Resource cleanup and storage release are separate obligations. Prove who performs both for each collector and tree teardown order; a small wrapper cache does not prove a small native heap.**
