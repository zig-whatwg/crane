# Architecture: A prediction that a later event confirms is a pool of bytes, not a pairing - move the bytes at the prediction, let every confirmation take from the pool, put the rest back when no confirmation can still come

**Date**: 2026-11-15
**Lesson**: When a number must fall at a prediction (inside a collection) and the event that makes it true comes later (the release that queues the tree), do not pair each prediction with its event. Keep one pool of predicted bytes inside the "dying" total; every confirming event takes its bytes from the pool before it takes from the live figure; when the last event that could confirm has run, what is left in the pool was wrong and goes back.

**Why**: Lane dm2's batch B takes a dead tree's bytes out of the DOM memory figure at the end of a full collection's marking, and batch A takes a tree's bytes out where the counts queue it. The same tree meets both: predicted in the pause, queued at the release a moment later. Without care it leaves the figure twice. Pairing them needs somewhere to carry the prediction - a field on each release record, or a map from root to bytes - plus rules for a tree that changed in between, a tree freed by a forced teardown before its release, and a tree that was never queued. The pool needs one counter and one invariant: `dying` = the queued items' shares + `predicted`.

**What Happened**: The design said "each release record carries the node count and the bytes the pass found for its tree". Writing the arithmetic showed that the per-record number buys nothing the pool does not: the queueing recomputes the same sum (the same walk, the same cap), so taking `min(sum, pool)` from the pool is exact when the prediction was right. When it was wrong in either direction the totals still close: a tree nobody predicted that dies in the window borrows from the pool, and the settle then puts back exactly as much less (tests/runtime/dm2_predicted_dead_test.zig, "the pool is bytes"). One case needed its own line: a predicted tree that a realm's forced end frees before its release would take its bytes off the live figure a second time and clip at zero, and the settle would then put back bytes that are gone. A free of more than the figure holds therefore comes off the pool (ExternalMemory.subDying).

**Fix**:
1. One pool counter beside the totals; state its invariant in the field's comment.
2. The prediction moves bytes live -> dying and into the pool (`predictDead`).
3. The confirming event takes from the pool first (`decideDead`), so the figure does not move at the confirmation.
4. Name the moment after which no confirmation can come (the adapter's drain emptied its release list; the agent's end) and put the pool back there (`settlePredictions`).
5. Find every other way the predicted bytes can leave (a forced free) and route its shortfall to the pool.
6. Count what was put back; where an exact per-item count is wanted for a decision, keep the items in Debug builds only (`DeferredTeardown.predicted_roots`).

**Takeaway**: **If a later event will recompute the same quantity, a prediction only needs to reserve it. Reserve in a pool with one invariant, let the events draw from it, and return the remainder at a named point - no record has to remember what was promised for it.**
