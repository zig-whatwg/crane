# Architecture: A move keeps the parent link until the new one - under counts, a parentless moment is a garbage moment

**Date**: 2026-11-07
**Lesson**: DOM "move" makes the node parentless between step 13 and step 20, but under reference counting a parentless node is a counted root: write the parent pointer once, at the new link, so the counts move from the old chain to the new one in a single step.

**Why**: Crane's counts decide garbage at a root (refcount.zig `lowered`: a tree whose root has no parent and a zero total is settled). A wrap (`wrapperRef`) or a `node_holds` hold taken and dropped on the moved subtree while its root has no parent walks up to that root, not to the old tree, and its release lowers the subtree's own total - possibly to zero, settling a tree that is about to be linked again. Worse, a hold taken while the node is parentless is counted only in the subtree; when the link moves `subtree_holds` from the old chain to the new one, the old chain loses a hold it never had.

**What Happened**: Lane move1 (moveBefore) approved a design that split `refcount.moveChild` into `detachForMove` / `attachForMove` so steps 14-16 (slot assignment) would see the node parentless, exactly as DOM says. Reading `unledgeredRef`/`unledgeredDeref` and `walkAdd` before writing it showed both hazards: the walk stops at the first parentless node, and `lowered` settles it. Nothing in steps 14-19 is guaranteed not to wrap or hold (slot assignment, transient observers, the old parent's children changed steps).

**Fix**: Keep `parent_node` = oldParent through steps 13-19 and write the new parent with `refcount.moveChild` at steps 20-21 ("the new chain gains first, so no total passes through zero"). Check what the standard's parentless node changes in between: the slot steps walk trees through child lists, which no longer reach the node, so they give the standard's answer; only a manually assigned slot inside the moved subtree reads its old root for one step, and step 24 assigns it again (stated in `mutation.move`).

**Takeaway**: **Before giving a moved node the standard's parentless moment, ask what the counts do with a parentless node: if a hold can start or end there, write the parent once, at the new link, and prove the steps in between give the same answer.**
