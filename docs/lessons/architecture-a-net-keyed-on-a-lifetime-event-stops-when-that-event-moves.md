# Architecture: A net keyed on a lifetime event stops catching when another change moves that event - fix the spec path it stood in for

**Date**: 2026-11-09
**Lesson**: A safety net that fires on one lifetime event ("the tree's last wrapper ends after its realm ended") quietly stops covering its case when an unrelated change moves that event (droppable wrappers now end in scavenges, while the realm still lives). The leak it caught was never its own: find the algorithm step it stood in for and implement that.

**Why**: Refcount 7a's ended-realm net (node_wrappers.endedRealmNet) frees a detached tree that is still held by its own pending work - an `<img>`'s "update the image data" holds its element with a counted reference - when the last wrapper reaching that tree ends after the tree's realm ended. It covered a hole in the Browser's end: the realm teardown ended an iframe's realm without HTML's "destroy a document" for its document, whose step 2, "abort a document", cancels that update. While wrappers lived until the Browser released them (non-droppable, few full collections), the net always saw a last wrapper end after the realm. The wrapper redesign's P7 left a node's wrapper unmodified, so P8 dropped it in a scavenge while the frame's realm still lived; the net never fired again, and the tree was alive at the agent's end.

**What Happened**: Lane wr1 batch 7. tests/html/parser_implied_end_tags_test failed alone (its 11 cases share one frame document); bisected to `<image src=x>` followed by a case with a nested iframe. Instrumenting the image's keep/release at P7 and at P6 (a scratch worktree at the P6 tip, the same probe) showed identical events - the update's hold taken and never released, no abort for the frame document - and a stack at P6 showed the net freeing the tree from `Browser.deinit -> drainAll -> runNetRoot`. The integrator ruled out extending the net (refcount 7b removes it): the fix was HTML "destroy a top-level traversable" step 2 at the Browser's end, every frame's document destroyed and its fetches aborted (dom.navigables.destroyDocumentsAtBrowserEnd), Blink's LocalFrame::DetachImpl -> StopAllLoaders.

**Fix**:
1. When a change makes a test leak, check whether a net freed that memory before (a stack from the old tip at the free is the fastest proof).
2. Name the event the net keys on and what moved it.
3. Implement the spec step the net stood in for; leave the net to its scheduled removal.

**Takeaway**: **A net that fires on a lifetime event is only as good as that event's timing. When a change moves the event, the net's leaks come back - fix the spec path it was covering, not the net.**
