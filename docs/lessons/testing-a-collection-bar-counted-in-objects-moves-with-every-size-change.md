# Testing: A collection test's bar counted in objects moves with every size change - state it in the bytes the collector paces by

**Date**: 2026-11-14
**Lesson**: A test that proves "the engine collects as the DOM grows" by counting live nodes after a fixed number of tasks fails when nodes get smaller, though nothing regressed: V8 collects at the same reported bytes, which is now more nodes.

**Why**: Crane tells V8 how many bytes of DOM each node holds (its Instance slot and its State block), and V8 schedules collections from that figure. The schedule is in bytes. A bar such as "fewer than 100,000 of 150,150 dropped nodes alive after 15 tasks" encodes one node size, and it sat on a knife edge besides: the answer depended on whether the first collection fell after task 5 or after task 6.

**What Happened**: Lane nm1's layout batch made a div 48 bytes and a Text 32 bytes smaller (reported: 224 -> 176 and 192 -> 160 bytes a node). tests/html/perf1_external_memory_test.zig read 100,096 alive against its bar of 100,000. The same workload run for 60 tasks, with the live nodes and the reported bytes printed per task, showed V8 collecting at 38.1 MB over the start with 192,188 nodes alive on main and at 36.9 MB with 230,226 nodes alive on the smaller nodes: the same bytes, 20% more nodes. The bar became: the DOM alive never passes 64 MB over the start (V8's own soft limit for external memory), it fell at least once, and the engine was told. Two runs proved the restated test still catches its fault: with the report to V8 switched off it fails ("peaked at 100903120 B ... it fell 0 times; the engine was told of at most 0 B"), and on main's layout it passes.

**Fix**:
1. Read what the mechanism under test paces by, and state the bar in that unit: bytes for an external-memory collection, not objects.
2. Run the workload long enough that "never collected" is far past the bar (here over 100 MB against 64 MB), so the bar is not a knife edge.
3. Print the object count on failure as an observation.
4. When a bar is restated, prove it in both directions in the same commit: it fails with the fault put back (a local patch), and it passes on the tree before the change.

**Takeaway**: **A bar in objects is a size pin in disguise: state a collection test's bar in the unit the collector paces by, far from the edge, and prove the restated test still fails for its fault.**
