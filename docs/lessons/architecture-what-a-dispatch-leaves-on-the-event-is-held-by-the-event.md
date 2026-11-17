# Architecture: What a dispatch leaves on the event is held by the event

**Date**: 2026-11-16
**Lesson**: State an algorithm writes into a long-lived object during a short hold - here the touch target list DOM's dispatch leaves on a TouchEvent - is the long-lived object's to keep alive. The dispatch's own references end with the dispatch; the event must count what it still names, and carry the teardown net for the one free no count prevents.

**Why**: DOM "invoke" step 5 sets the event's touch target list to the path item's retargeted list, and dispatch step 11 clears it only when clearTargets is true. After a dispatch the event therefore names retargeted targets - a shadow host - that are not the touches' own targets, so the touches do not keep them. The next dispatch of the same event starts from that list (step 6.1). In Crane the list was bare pointers: the path held its nodes for the dispatch, and nothing held them after it.

**What Happened**: Lane ev2 was asked to make the path count its touch targets (a gap lane lk1 found by reading). The red test for the neighbouring case - keep the event, move the touch's target out of the host's shadow tree, drop the host, collect, dispatch again - failed on main with no mutation at all: the second dispatch read `NEWCOMER`, a new node in the freed host's slot. A use-after-free reachable from script, on both OSes. Counting the list fixed it; a third test then showed the count is not enough when the host belongs to another realm: a removed frame's realm ends once the collector has taken it and frees its nodes whatever counts them, so the list read a freed node again.

**Fix**:
1. When an algorithm stores a pointer into an object that outlives the algorithm, ask who holds the pointee after the algorithm's own references go. Here: `TouchTargetList` takes one counted reference per node it names (append, assign - the new ones before the old ones go - clear, deinit), as WebKit's TouchEvent keeps counted TouchLists.
2. Give every counted holder that can name a node of another realm the generation net (`forgetFreed`: slot reissued or teardown begun -> the list is emptied before a dispatch reads it). A count keeps a node from the collector, not from its realm's end (docs/lessons/architecture-a-traced-edge-keeps-an-object-from-the-collector-not-from-its-realm-s-end.md says the same of a traced edge).
3. Test the retained state, not only the algorithm: dispatch the same event twice with a collection between.
4. Write the neighbouring red tests even when the brief names one gap: the one that failed without a mutation was not the one asked for.

**Takeaway**: **A dispatch's holds end at dispatch step 9; whatever the dispatch wrote into the event stays. Every pointer an event keeps between dispatches needs its own reference and its own realm's-end net - and a second dispatch of a kept event is the test that finds the ones that have neither.**
