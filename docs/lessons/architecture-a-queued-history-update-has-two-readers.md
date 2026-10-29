# Architecture: A queued session history update has two kinds of reader

**Date**: 2026-10-29
**Lesson**: When the spec splits a synchronous history update from its queued finalize, sort the readers first. Script's views (history.length, navigation.entries(), history.state) read the history as if the update were already listed. Only the traversal endpoints read the listed history.

**Why**: HTML's "URL and history update steps" and "navigate to a fragment" make the new entry the navigable's active entry at once. "Finalize a same-document navigation" lists it later, on the traversal queue. A traversal queued before the synchronous navigation must compute its endpoint from the ORIGINAL placement: overlapping-navigations-and-traversals/same-document-traversal-same-document-nav says so, and so do the spec's queue-jumping examples. So the traversal endpoints (`stepByDelta`, `usedSteps`, `entryAt`) cannot see the new entry until its finalize runs. Every other reader can, and the browsers show it at once. html/browsers/history/the-history-interface/001.html checks that a frame's location.hash and pushState() change its PARENT's history.length synchronously. The spec's text would update the parent only at the finalize's step 18.

**What Happened**: Lane nav2 E's first design kept one explicit view per navigating document and left the others' views until the finalize. Reading 001.html while a compile ran showed that this would lose PASS names the old synchronous commit had. The design also collided with two open spec bugs:
- whatwg/html#10232: the literal finalize step 2 drops the first of two synchronous navigations in one task;
- whatwg/html#12961: a jumping finalize prunes a traversal's retained target.
The browsers keep every entry and abort the pruned traversal.

**Fix**:
- Pending entries are flagged entries in the joint list, with no step, and they form a FIFO chain per navigable.
- `writeViews` computes every view from a PROJECTED history: the pending pushes stacked one step on each with the forward history cleared, and the pending replaces put in place.
- The traversal endpoints, `stepByDelta` among them, read only the listed entries.
- The finalize lists its entry, earlier ones of the chain first, and applies its push/replace step inline. A finalize that jumps a waiting traversal (14.1) runs nested from the queue's service task.
- A traversal's activation drops the chain. An inline cross-document commit lists it first.

**Takeaway**: **Before moving a spec step behind a queue, list who reads its effect. Script's views follow the browsers, which show the update at once. Only the readers the spec's ordering exists for - here the traversal endpoints - wait for the queue.**
