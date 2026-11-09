# Architecture: Moving objects out of a mechanism moves the nets it carried

**Date**: 2026-11-09
**Lesson**: When node wrappers left the wrapper cache, the cache's realm-end sweep stopped meeting nodes. That sweep was more than "the cache's end": it was refcount step 7a's net, the count-blind free of a realm's detached trees. Before taking objects out of a mechanism, list every free it made for them, including the ones its name does not mention, and give each a new home or a decision to drop it.

**Why**: P2's design said "the realm's end no longer releases node wrappers", which is true for the wrappers' counted references. But WrapperCache.deinit also freed every detached root it had an entry for, whatever its counts (PHASE 2), and every collected root whose finalizer had not run yet (PHASE 0, through finalizeEntry's coordinated-teardown branch). Some holders count their own element and let go only when it is torn down: an `<img>`'s image update, a dialog's close watcher. Their trees had relied on that net.

**What Happened**: PRE gate 1 on server1 failed five tests-html tests, each with "N node(s) alive at the agent's end: held past every realm's end, freed only by the final sweep". The cases were an img with a pending update, a dialog close watcher, and a frame's document tree that document.open() replaced. A diagnostic patch printed each live node's holds chain, vtable and realm. The counts were held by a CountedRef with no chain, on nodes of ended realms whose wrappers had already gone. In production such a tree stays until the Browser ends: a leak per page.

The first restore freed every wrapped detached root of an ending realm (c3673e0d458). The integrator asked whether it could free a frame's node that its parent's script still holds. It could not in practice: a node's one wrapper is its relevant realm's, so the parent's hold keeps the frame's realm alive. The net was still narrowed to trees no wrapper reaches (05f864c5cc3):
- endRealm frees the ending realm's detached roots whose wrapper is already collected;
- endedRealmNet frees an ended realm's still-held detached tree when its last wrapper goes, in a queue slice, never in the collection.

**Fix**: node_wrappers.endRealm (from WrapperCache.deinit) and node_wrappers.endedRealmNet / runNetRoot. Tests: tests/html/wr1_realm_end_net_test.zig, plus the five holder cases under the poisoning allocators. Refcount step 7b removes the net once holders cancel their work when their realm ends (Blink's ContextDestroyed observers).

**Takeaway**: **A mechanism's free paths are a contract other code leans on. When objects leave it, enumerate what it freed for them and why, and re-home each free, narrowed to what is safe now. Otherwise "the counts decide" quietly turns into "nothing decides" for whatever leaned on the old free.**
