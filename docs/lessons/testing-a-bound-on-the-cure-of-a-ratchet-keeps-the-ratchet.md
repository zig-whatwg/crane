# Testing: A bound on the cure of a ratchet keeps the ratchet - measure the bounded variant before proposing it

**Date**: 2026-11-14
**Lesson**: When a pass removes garbage from a figure a collector sets its limit from, capping the pass's work does not give a proportional share of the gain: what the cap leaves in the figure raises the limit, the next collection has more garbage, and the cap covers less of it each time.

**Why**: The limit after a collection grows with the figure. Garbage left in the figure makes the next collection come later and kill more; the same cap then removes a smaller fraction. The loop that the uncapped pass breaks is the loop the cap leaves running.

**What Happened**: Lane dm1's end-of-marking pass walks the trees that die in a collection (2 to 29 ns a node) to take their bytes out of the figure V8 is told. To bound the pause I added a budget of nodes per collection, the rest left to the later release. On 3,000 dropped clones of an 841-node tree (server1) the product peaked at 380 MiB and the unbounded pass at 161 MiB; with a budget of 20,000 nodes the peak was 369 MiB and with 100,000 nodes 318 MiB. The pass itself fell to 0.2 and 0.85 ms, as designed, and bought almost nothing. Unbounded, the garbage per collection had already shrunk from 695,000 nodes to about 210,000 because the limit stopped climbing - the cure bounds its own cost better than a cap does.

**Fix**:
1. Prototype the bounded variant with the same switch as the unbounded one and run both before writing "bound it" into a design.
2. Report the cost of the unbounded pass per unit (per dying node), the units per collection WITH the cure in place, and the worst case measured.
3. If the cost must leave the pause, remove it (keep the answer ready: a total maintained as the tree is built) instead of truncating it.

**Takeaway**: **A feedback loop is not partly broken by partly fixing it. Measure the capped version: here a cap that cut the pass's time by 10 to 50 times kept 72 to 95% of the memory the full pass saved from being saved.**
