# Architecture: A memory bound must weigh each item in its own unit

**Date**: 2026-11-06
**Lesson**: The deferred teardown queue's bound counts nodes (`high_water` = 100,000), but each garbage tree was weighed at most 64 of them, so the bound really admitted 1,562 trees of any size.

**Why**: The queue frees garbage trees a slice at a time between tasks. Past `high_water` queued nodes, the next binding exit back into script frees down to it, so a script that makes garbage cannot grow the queue without bound. The bound is in nodes. The weight at push was `countUpTo(root, weight_cap = 64)`, "so a removal stays O(1)". Its slices then took at most the item's weight off `pending` for every node they freed. A 900-node tree therefore counted as 64 coming in and 64 going out. The bound held the count of trees steady, not the count of nodes.

**What Happened**: Perf round 0's innerhtml page (`dom.inner-html-set`: 300 innerHTML replacements of a 900-node list per sample) reached 3.6 GB. Chrome's figure for the same page is 397 MB. Lane perf1 ran gc_bench in release at the page's 3,900 replacements and found 1,392,020 live instances and 9 wrappers: every one was a queued garbage node. The equilibrium predicted from the cap is pending ≈ high_water + one tree, which is 1,562 trees × 900 nodes = 1.41M nodes. A forced collection drained the queue, and the instances went back to 911. refcount9's handoff had already named the undercount for a Document's garbage item ("the queue's `pending` undercounts such trees").

**Fix**: `refcount_teardown.settle` weighs a garbage tree with `countUpTo(root, DeferredTeardown.high_water)`, which is its whole node count capped at the bound itself. The document-unreferenced item already weighed its tree that way. The walk is one read-only pass over a tree its slices will free anyway, so it is amortized against the free. Tests:
- tests/v8/deferred_teardown_test.zig: a dropped 4,001-node tree weighs 4,001, and a Document of 102 nodes weighs 102. Both read 64 before the fix.
- tests/html/perf1_garbage_weight_test.zig: one script does 150 replacements of a 1,001-node list. At the script's end 150,151 objects were alive before the fix; with it, live objects stay near high_water.

**Takeaway**: **A bound is only as good as the weights it sums: weigh every item in the bound's own unit. A capped estimate turns a bound on nodes into a bound on trees, and the trees can be any size.**
