# Architecture: The order of a session history update is observable only through each document's own view

**Date**: 2026-10-26
**Lesson**: HTML's "finalize a cross-document navigation" adds the new entry before the old document unloads, yet no document sees it then. The leaving document keeps its History length/index and Navigation entries, and the traversable's other documents get theirs only at "apply the history step" step 18. Moving Crane's record of the entry earlier without those per-document views regresses what script observes.

**Why**: Crane reads history.length/index, navigation.currentEntry and navigation.entries() live from the JointHistory. Recording after the unload is what makes those live reads give the spec's answers during pagehide, unload and pageswap. Record first, and the leaving document's pageswap check `activation.from === navigation.currentEntry` and its parent's and siblings' history.length all show the new entry too early.

**What Happened**: Lane newwin1's approved design moved "finalize" before the unload (S2), with only the leaving document's History length/index frozen (S1). Checking what each view reads showed:
- Navigation.currentEntry is live as well, so 13 pageswap files would break (the reserve-identity lesson's).
- The other documents' length would move during the child's unload, where today it is correct.
The integrator moved S1 (full) and S2 to the batch with the session history traversal queue, which needs the same per-document machinery (apply step 18, synchronous navigation steps).

**Fix**: Keep record-after-unload as a stated deviation, with a commit-site comment (HTMLIFrameElement runCommit). Build the per-document History length/index for every document, plus a per-document Navigation entry list and currentEntry, before moving the record.

**Takeaway**: **Before reordering a spec step to match the text, list every view through which script can observe its effect. If those views are live reads of shared state, the order is all that keeps them right: build per-document views first, then reorder.**
