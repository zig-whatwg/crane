# Architecture: A dying tree's holds stay on its root - unlink for teardown without moving counts

**Date**: 2026-10-10
**Lesson**: When counts are kept along a tree's chain, a teardown that unlinks children should leave the counts where they are and let the root's own free take the whole total out - moving them per child costs an O(depth) walk and a document lookup per freed node, and half-moving them (re-rooting the child without walking) counts its holds twice.

**Why**: Reference counting step 3 (tmp/plans/refcount-design.md, lane rc3) keeps `subtree_holds` along the host-including chain, and a Document's `foreign_holds` sums the totals of its detached roots. A tree is freed three ways: Node.deinit's recursive walk (children freed while still parented), defertd's sliced teardown (`tree_teardown.unlinkLastChild`, leaves first), and a host's teardown that leaves its shadow root or template contents alive.

**What Happened**: The obvious design treats a teardown unlink like a DOM removal: subtract the child's total along the old chain, make the child a detached root of its document, and subtract it again when the child is freed. That is correct but walks ancestors that are themselves being freed - O(depth) per node of a tree defertd frees in slices of 512 - with a document lookup each time. The cheap half-measure (flag the child as a detached root without walking) is wrong: the dying root still subtracts its full original total at its own free, so the child's holds leave `foreign_holds` twice.

**Fix**:
1. `refcount.unlinkForTeardown(child)` writes the pointer and the parent bit only.
2. `refcount.nodeFreed(node, counts)` (Node.deinit) subtracts `subtree_holds` from the document only for a node flagged `foreign` (a detached root). A child freed under a parent was never flagged, so it subtracts nothing; the root subtracts the whole tree's total once.
3. A hosted root that survives its host (`hostGone`) adds its own total to its document: the dying root's subtraction already includes it, so the books come out even.
4. Document lookups at a free go through the owner that keeps the document's slab generation (Node's accessor), never through a pointer that may name a freed document.

**Takeaway**: **In a dying tree, the root owns the books: unlink children without moving counts, and settle the whole total once, at the root's free.**
