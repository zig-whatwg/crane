# Testing: A cost row that wraps nodes and forgets them is two-valued - a young collection decides which wrappers a full one then keeps for good

**Date**: 2026-11-15
**Lesson**: A benchmark that wraps the nodes of a kept tree once and never touches the wrappers again measures a race: an untouched wrapper is dropped by a young-generation collection, but one still there at the next FULL collection is promoted and the tree walk keeps it from then on. The row then has two values on one binary, and a change that moves a collection by a few kilobytes flips which one a run reports.

**Why**: Since the wrapper redesign's P8 an unmodified node wrapper is droppable in a scavenge, and since P7 the walk keeps every wrapper of a tree a reachable wrapper belongs to. gc_bench's `pause` row builds a tree of 10,100 elements, wraps each with `for (const e of r.querySelectorAll('*')) void e`, keeps the root, and forces a full collection every 10,000 cycles. Whether the second scavenge comes before the first forced full collection decides whether 2 or about 6,000 wrappers are walked in each of the 80 collections that follow.

**What Happened**: Lane nm2's cost window (node State blocks 16 bytes smaller) read the row at 8,951 M instructions against main's 8,161 M (+9.7%) and a p95 pause of 1,221 us against 970. The counters named it: 6,101 node wrappers alive at the end against 2, 488,160 walks against 240, 4 young collections against 5. Run again, the tip gave 8,158 M with 2 wrappers and 8,921 M with 5,908; main's own five rounds in the window were 966, 973, 929, 970 and 1,217 us. Two controls on both binaries settled the work per node: every wrapper modified (`e.k = 1`, none droppable, 10,102 kept) 9,826 / 9,813 M against 9,816 / 9,832 M; no wrapper below the root 8,010 / 8,015 M against 8,006 / 8,009 M.

**Fix**:
1. Read `node_wrappers`, `node_wrapper_walks` and `minor_gc_count` beside any pause or instruction figure of a row that wraps nodes; a difference there is a different experiment, not a cost.
2. Give such a row two fixed forms: every wrapper modified (the walk's cost per wrapped node) and no wrapper made (its cost per unwrapped node). Compare those; never the form that leaves it to a scavenge.
3. Before calling a row a regression, run each side several times and look for a second value on the BASE.

**Takeaway**: **A row whose result depends on which collection reaches an untouched wrapper first is a coin, not a measurement: pin what the collector may drop, then compare.**
