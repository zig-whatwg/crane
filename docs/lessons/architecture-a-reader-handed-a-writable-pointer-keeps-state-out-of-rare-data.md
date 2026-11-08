# Architecture: A reader handed a writable pointer keeps state out of rare data - split the read path from the ensure path

**Date**: 2026-11-08
**Lesson**: State that almost no object uses can move to rare data only if the readers that visit every object never make it. A hook that hands out one writable `*State` to readers and writers alike pins that state inline on every object. Give readers a `*const` view that falls back to one shared, read-only empty state, and give writers an `ensure` path: the readers then make nothing, and the compiler finds every writer.

**Why**: An accessor that returns `*State` serves two kinds of caller with one contract. If the state moves to a block made on demand, that accessor has to make the block before it can return the pointer - and the readers on hot walks (an event's path, innerText, the style engine) then make it for every node they pass. The old comment said exactly that, and it was the reason the state stayed inline.

**What Happened**: Lane perf3 E1 item 2. DOM 4.2.2.2's slottable state (assigned slot and manual slot assignment, 64 bytes as two NodeRefs) sat in every element's InternalState. None of the perf pages' 3,039,618 elements was ever assigned a slot. `dom.slot_helpers.slottable(node)` returned `{ state: *SlottableState, name }` and served ten readers and four writers. The split:
- `slottable(node)` hands out `*const SlottableState`: the element's own (in ElementRareData) or `&unassigned`, a `pub const` with neither slot. It never allocates.
- `ensureSlottable(node)` returns `*SlottableState`, making the rare data. Only "assign slottables" step 4 and HTML assign() step 3.2 call it, for the nodes they assign. Both make every state before anything changes, so running out of memory still changes nothing. The clearing steps ensure only a state that already names a slot, which is the node's own.
- Changing `state` to `*const` made the four writer sites fail to compile. No reader had to change.
Element 200 -> 136 B, a div's block 432 -> 368 B. Blink does the same with NodeRareData's FlatTreeNodeData: Node::EnsureFlatTreeNodeData for the slot that assigns, and GetFlatTreeNodeData, null otherwise, for everything else.

**Fix**: For a field you want to move to rare data:
1. List its accessor's callers and sort them into readers and writers.
2. Readers get a `*const` view; a node without the block reads a shared `const` default (read-only memory, so a stray write faults instead of corrupting every node).
3. Writers get `ensure`. Make the block before the algorithm's first change when the algorithm promises that a failure changes nothing.
4. Pin with tests: a size pin; "a walk of every reader makes no rare data"; writers make it; both exits free it under a poisoning allocator.

**Takeaway**: **A shared accessor that returns a writable pointer is why cold state stays inline: give readers a `*const` view over a shared empty default and writers an `ensure` path, and let the compiler list the writers.**
