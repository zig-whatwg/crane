# Architecture: A list in a block that moves is read per step, and its slot is reserved before it grows

**Date**: 2026-11-16
**Lesson**: When a value's address lives in a block that reallocates (a node's sparse rare block), every holder reads it again after anything that can run script, and a step that grows the value gives the block its slot BEFORE the growth, so the write-back cannot fail.

**Why**: Lane nm3 moved a node's event listener list from a word of its State (a fixed address for the node's life) into a slot of its rare block. Two blocks can now move under a dispatch: the rare block (a listener reads `el.classList` for the first time) and the list's own block (a listener adds listeners). EventTarget's impl held `*InternalState` across callbacks in inner invoke; the same pointer into the rare block would dangle after the first callback that touched `el.style`. And "grow the list, then store its new address" has a failure order: if the store needs the rare block to grow and that allocation fails, the slot still names the list's OLD block, which realloc already freed.

**What Happened**: The impl now goes through a `Listeners` handle - the node's NodeBase (stable) or, for a target that is no node, the list's fixed address - whose every call reads the slot. A read of the slot is a block test, a bit test and a popcount, and the first version paid it on every accessor call (`len`, `view`, `next`, `watched`); the add, remove and dispatch paths now read once per step that can run script (after each callback), not once per listener skipped by type or phase. A listener add that finds room in the list's block writes nothing back.

**Fix**:
1. No pointer into the block: by value out (`NodeBase.eventListeners()`), through the holder in (`setEventListeners`).
2. Growth order: `reserveEventListeners()` (may move the rare block; nothing else changed if it fails), then grow the list (the list's block moves; the rare slot is stale for exactly these lines, with no call between), then `setEventListeners` (in place, cannot fail).
3. Script before the handle: `addEventListener` flattens its options - getters - before it takes the handle.
4. A handle that outlives a callback checks that its node still stands (`NodeBase.stands`): the callback may have ended the node's realm.
5. tests/html/nm3_node_listeners_dispatch_test.zig and tests/wpt/crane/nm3-node-listeners-in-rare-block.html grow both blocks under a dispatch.

**Takeaway**: **For state behind a moving block: read by value after every call that can run script, reserve the slot before the value grows, and count the reads on the hot path - one per step, not one per accessor.**
