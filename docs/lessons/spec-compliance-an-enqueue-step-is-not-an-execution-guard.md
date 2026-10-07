# Spec Compliance: An enqueue step is not an execution guard

**Date**: 2026-10-05

**Lesson**: Moving an algorithm's early return ahead of its queueing step can change when older work runs, even if the newly queued operation itself does nothing.

**Why**: Custom-element queues hold elements separately from each element's reaction queue. Enqueueing an element on a nested CEReactions scope makes that scope invoke the element's already-pending reactions too.

**What Happened**: An extra custom-state check in tryToUpgrade skipped precustomized elements. During an upgrade constructor, reinserting `this` therefore failed to enqueue it on the insertion scope. Its pre-construction attribute and connection callbacks ran after constructor:end instead of before it. The new ce-upgrade-reentrant-insertion Crane test exposed that exact ordering difference.

**Fix**: Follow HTML's two distinct algorithms. Try-to-upgrade looks up the definition and enqueues an upgrade reaction without checking state. Upgrade-an-element performs its own step-1 state check when that reaction executes. Its failure cleanup also preserves the failed/precustomized state reached before the exception, as step 10 requires; it clears only the definition and reaction queue.

**Takeaway**: **Queue membership has observable effects independent of the queued operation's body; preserve the spec's placement of guards.**
