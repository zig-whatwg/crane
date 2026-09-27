# Architecture: A heap address moves when the GC compacts

**Date**: 2026-09-26
**Lesson**: `v8_Context_GetRawAddress` returned the NativeContext's heap address, and context_manager keyed every realm by it - but a compacting collection relocates contexts, so a realm registered before a full GC was no longer found after it.

**Why**: The function read the tagged pointer behind the handle (`*reinterpret_cast<void**>(*ctx)`), a location in V8's heap. Full collections evacuate sparse pages; objects on them - contexts included - move, and V8 updates its own references, not the embedder's copies of the address. Its comment said "stable across handle conversions", which is true and beside the point: stable across conversions is not stable across GCs.

**What Happened**: The page-realm lane measured it in tests/v8/page_realm_operations_test.zig: the file's realm registered at 0x1e0b00180099, and after the earlier tests' forced full collections the same context was at 0x1e0b00240091; `context_manager.get()`, `entryRealm()`, `functionRealm()` and `getWindowForContext` all missed. In a browser any full compaction during a page's life can orphan its realm entry, and a context moved onto a freed address can alias another realm's - the recycled-address shape of [A stale weak callback's Registry.remove evicts the LIVE entry](architecture-a-stale-weak-callback-s-registry-remove-evicts.md).

**Fix**: The key is now a never-reused id the wrapper stores in the context's embedder data (index 1; 0 is V8's old debugger slot) the first time it is asked for - Blink's V8PerContextData model. A native context's embedder-data array starts empty, so an unset slot is never read; contexts built in snapshot mode get no id (a snapshot must not carry pointer embedder data). Test: contexts interleaved with old-space garbage keep their key across forced full collections.

**Takeaway**: **Never key anything on where a GC-managed object lives; give it an identity it carries with it.**
