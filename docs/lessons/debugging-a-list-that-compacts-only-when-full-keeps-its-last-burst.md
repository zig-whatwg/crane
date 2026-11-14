# Debugging: A list that compacts only when it is full keeps its last burst for ever - and a move is not a removal

**Date**: 2026-11-14
**Lesson**: A record list whose stale entries are dropped "when it is full, at the next append" never drops them after the last burst, and never returns capacity; and a bookkeeping hook on "removed" fires for every MOVE unless the mover says otherwise.

**Why**: A realm records every node removed while no wrapper reaches it (runtime.orphan_roots), so its end can free a removed tree nothing else frees. The list compacted only when an append found it full, with `shrinkRetainingCapacity`. "Insert" of a DocumentFragment removes each of the fragment's children and links it into the parent a step later: every such child was recorded, and was stale the moment it was linked.

**What Happened**: The published "span, parsed (innerHTML)" row read 489 B per span against 231 B for the same node made another way. In the release console (vmmap and malloc_history at three marks: before, after one innerHTML of 100,000 spans, after a second one into a second host) the first parse added 482 B per span: 231 the node, 229 freed pages malloc keeps dirty (the second parse reused them and cost 231), and 22 one live 2.2 MB block under `mutation.removeHeld <- insert <- replaceAll` - 100,000 stale records, kept to the realm's end because no later append ever found the list full.

**Fix**:
1. Account a footprint row in three parts before blaming the object: the object, what something else KEEPS (malloc_history by site), and freed-but-dirty pages (vmmap's "(empty)" rows). Repeat the workload once in the same process: what is reused was a peak, what grows again is kept.
2. A caller that removes only to link again uses the removal without the record (`removeHeldMoving`), and records what it leaves unlinked on its error path.
3. A list that compacts gives its room back when the compaction leaves it mostly empty.

**Takeaway**: **"Compact when full" is no bound after the last burst, and "removed" hooks see every move: split a footprint into object, kept and freed-dirty before charging it to the object.**
