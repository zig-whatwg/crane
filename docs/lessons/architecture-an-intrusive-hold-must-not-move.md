# Architecture: An intrusive hold must not move - take it once its container stops growing

**Date**: 2026-10-24
**Lesson**: A `node_holds` hold (Hold, MemberHold, TaskHold, RefHold) is a link in its node's doubly linked chain (`NodeBase.holds`). Embedded in something that can move - an item of a growable list, a value copied out of a struct - it leaves the chain pointing at the old address, and the next removal or free walks into freed or reused memory.

**Why**: The chain is how a hold survives its node: `nodeReleased` walks it when a node's storage goes and empties every hold on it, so a later `release` writes nothing to the freed node. That needs the hold's address to be stable from link to unlink. Every holder until refcount step 5g embedded its holds in an arena block or a heap state that never moves (a range's state, a collection's state, a task record).

**What Happened**: Refcount step 5g (lane refcount4) gave each item of an event's path a hold on its invocation target, WebKit's EventContext `RefPtr<Node> m_node` (Source/WebCore/dom/EventContext.h). The path is an `infra.List(PathItem)` that `dom.event_path.build` appends to, and an append can reallocate the list. Linking each item's hold in `append` would have moved linked holds on the next reallocation. The design took the holds only after the build ended, and released them in `clearPath` before the path is emptied.

**Fix**:
1. `EventState.holdPath` links every item's hold once `build` has appended its last item. `releasePath` unlinks them in `clearPath` and `EventState.deinit`, before the list is cleared or freed.
2. A `path_held` flag and a Debug assert in the path's `append`: nothing grows the list while its holds are linked.
3. For any new holder: embed the hold in storage that does not move until the hold is released - an arena block, a heap state, a stack frame that outlives the call - and release it on every path that frees that storage (deinit, and any sweep that frees the block without deinit).

**Takeaway**: **A hold is an address in someone else's list: put it where nothing moves it, take it after the container is final, and release it before the container is freed.**
