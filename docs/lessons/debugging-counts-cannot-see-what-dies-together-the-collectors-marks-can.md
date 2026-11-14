# Debugging: Reference counts cannot see two things that die in one collection - the collector's marks can

**Date**: 2026-11-14
**Lesson**: To predict, inside a collection, what a dead wrapper's release will free, do not replay the release on the reference counts; use what marking proved - a wrapper found dead means nothing the collector kept reaches its tree, so every reference left on the tree is another dead object's or a native one.

**Why**: A reference-counted tree can be held by a second collected object (a NodeList holds its root counted, a MutationRecord its target). When the node's wrapper and that holder die in the same collection, each still counts on the node until its own finalizer runs later. A replay of "the wrapper's reference goes; is the total zero?" finds the holder's reference and concludes the tree lives. Crane's marking walk keeps every wrapper of a tree as soon as one wrapper, one pending-activity keep or one kept holder of it is reached (dom.wrapper_tracing), so a dead wrapper is itself the proof that no kept holder exists.

**What Happened**: Lane dm1's first prediction rule replayed the counts. On gc_bench loops (trees held by one wrapper) it matched. On the perf suite's parser page it predicted 0 MB of the 55.6 MB that died in the first collection: the page reads `div.childNodes.length`, and the NodeList's hold kept every div "alive" in the replay. The rule built on the marks (the tree dies unless its ROOT is natively held: a remover's hold, or a Document's count beyond its dead wrapper and its own pending work) predicted 58,330,592 B, 37,649,344 B and 59,829,920 B at three collections against 58,331,568 B, 37,661,152 B and 59,890,208 B queued afterwards. What it cannot see is a native reference below the root; that error is one cycle long and makes the figure too low, the safe direction.

**Fix**:
1. Ask what the collector's result already proves before simulating the embedder's bookkeeping.
2. Test a prediction on a page whose script touches collections (`childNodes`, `children`, `querySelectorAll`), not only on loops that hold a tree by one wrapper.
3. Log the prediction beside what the release then does (bytes predicted, bytes queued), per collection; a rule that reads 0 while memory falls half a second later is wrong, not conservative.
4. Check that an estimate's error goes in the safe direction and corrects itself, and say for how long it lasts.

**Takeaway**: **Counts say who still points at a thing; marks say who is alive. When several objects die together, only the marks know - build an in-collection prediction on the collector's proof, not on a replay of the counts.**
