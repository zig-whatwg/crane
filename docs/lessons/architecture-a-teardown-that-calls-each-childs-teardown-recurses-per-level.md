# Architecture: A teardown that calls each child's teardown recurses once per tree level

**Date**: 2026-11-08
**Lesson**: Node.deinit tore its children down by calling each child's teardown, whose own Node.deinit did the same: one set of native frames per tree level, so any page that built a 10,000-deep tree crashed the process when the tree went - free a subtree leaves first, unlinking each node before its own teardown, so no teardown ever has a subtree to walk.

**Why**: A tree's depth is page input (`'<div>'.repeat(n)`, an appendChild loop). A destructor chain - the type's deinit, its ancestors', Node's, then each child's - is ordinary-looking code with no loop in it, so the recursion hides across several files and a vtable; it does not show up in a grep for recursive functions. The crash lands in whatever frame reaches the guard page (here IntersectionObserver.targetDestroyed), not in the recursion's own code.

**What Happened**: Lane crash1's batch-1 sweep found every 10,000-deep tree SIGSEGV at its teardown - in the WPT runner when the next file started, so it was charged to the wrong file. The chain was Node.deinit -> deinitNodeByType -> deinitElement -> the vtable's deinit -> ... -> Node.deinit, about 3-4 KiB a level in Debug. The collected-tree slices (`tree_teardown.freeDescendants`) were already iterative; the realm's end, an orphan's teardown and a template's contents were not.

**Fix**: `dom.tree_teardown.freeAllDescendants(root, &deinitNodeByType)`: descend to the last leaf, unlink it from its parent, run its teardown (which now has no children), climb, repeat - the tree's own links are the queue, no list and no allocation; the slices share the walk. WebKit unlinks every child before its last reference goes (ContainerNodeAlgorithms.cpp removeDetachedChildrenInContainer); its old deletion queue, which Blink shared until Oilpan, reused nextSibling as the queue link. tests/html/crash1_deep_teardown_test.zig drops 10,000-deep trees by every exit (realm end, collected root, orphan, template, final sweep) on a pinned 8 MiB thread under a leak-counting DebugAllocator; 3 of 7 crashed before the fix.

**Takeaway**: **Any teardown that frees what a node owns by calling the owned node's teardown is recursion over page-controlled depth: walk the structure from outside, leaves first, and unlink each node before its own teardown runs.**
