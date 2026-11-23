# Architecture: A Zig function nothing references is never analysed, so a stale body can sit in the tree unbuilt

**Date**: 2026-11-22
**Lesson**: Zig analyses a function only when something references it, so a function whose types went away still "builds" until its first caller. A grep for `page_allocator` or any other pattern can land on code that was never compiled, and that code is evidence of nothing.

**Why**: Zig's semantic analysis is lazy. `pub` changes nothing, and neither does importing its module (`_ = dom.tree;` in lib_exports.zig). Only a reference to the function itself makes the compiler look at its body. A body that names a field its type lost, or returns the wrong pointer type, is an error nobody sees.

**What Happened**: Lane leak3 (fixing `std.heap.page_allocator` uses in src/) found two of them inside such code: `compareTreeOrder` in src/dom/tree.zig and `compareTreeOrder`/`findCommonAncestor` in src/dom/tree_helpers.zig. The plan was to rewrite them allocation-free behind a test that pinned their results. That plan was dropped when it turned out nothing calls them (`grep -rn` over src/, tests/ and tools/ for every name, qualified and bare) and they could not compile if called:
- tree.zig takes `*const interfaces.Node` and reads `.parent_node` and `.next_sibling`. The generated interface has no such fields; NodeBase has them.
- tree_helpers.zig appends NodeBase pointers to an `infra.List(*const interfaces.Node)`.
- Both date from before the node data moved to NodeBase.

Every other function in tree.zig, and 28 of tree_helpers.zig's 46, are unreferenced bodies of the same kind (listed in the deletion commit). The live tree-order code is src/dom/boundary_points.zig and Node.compareDocumentPosition.

**Fix**:
1. Before changing code a grep found, check that something references it: grep its name over src/, tests/ and tools/, qualified and bare, and its module's import aliases.
2. Unreferenced and uncompilable: delete it in a commit of its own, saying how you proved there are no callers, so the deletion bisects cleanly. Do not rewrite or test code that has no callers.
3. Unreferenced but worth keeping: give it a test that calls it. A test is a reference, so the compiler then holds the body to its types.

**Takeaway**: **In Zig, "it builds" says nothing about a function nothing calls: an unreferenced body is never analysed, so check for a caller before fixing, testing or citing such code.**
