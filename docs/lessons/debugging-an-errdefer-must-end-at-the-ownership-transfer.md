# Debugging: An errdefer must end at the ownership transfer

**Date**: 2026-10-02
**Lesson**: A cleanup registered before a map insertion must stop owning the key when the insertion succeeds, and an existing-key lookup must free its temporary key exactly once.

**Why**: `errdefer allocator.free(key)` remains armed for every later error in the function. Inserting the key into an owning map does not disarm it. Explicitly freeing a temporary lookup key does not disarm it either.

**What Happened**: IndexedDB factory `open` freed its lookup key on the existing-database path, then allocated a connection. On the new-database path it inserted the key and metadata before allocating that connection. An allocation failure therefore freed the lookup key twice or freed a key still held by the map. A `checkAllAllocationFailures` walk across new and repeated opens reproduced a segmentation fault in the factory's teardown when it freed the map-owned key again.

**Fix**: Keep the lookup key under one defer with an explicit ownership-transfer flag. Allocate and initialize the connection before inserting metadata, so no fallible work follows insertion. Set the flag only after successful insertion. Keep the connection under errdefer until returning its request. Run the allocation walk using `std.testing.allocator` so every failing allocation also checks cleanup.

**Takeaway**: **Ownership transfer must change the cleanup that will execute, not merely the data structure holding the pointer. Exercise both new-key and existing-key paths in allocation-failure walks.**
