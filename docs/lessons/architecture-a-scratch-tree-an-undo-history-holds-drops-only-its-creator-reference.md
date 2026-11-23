# Architecture: A scratch tree an undo history holds drops only its creator reference

**Date**: 2026-11-23
**Lesson**: A native creator that parses a scratch tree and lets a history keep nodes of it must end only its creator reference (`dom.refcount.releaseCreatorReference`) when it is done, never `dom.node_creation.releaseIfUnwrapped` / `destroyUninserted` while the tree still has children: those free the whole tree at once, whatever holds its nodes.

**Why**: `destroyUninserted` is the creator's "nobody but me ever saw this" free - it tears the tree down now, past any RefHold on its nodes. Since refcount step 7 the counts decide frees: a root that loses its creator reference is queued for teardown only when nothing in its tree is held (`refcount.lowered` -> `refcount_teardown.settle`), so ending the creator reference alone frees it as soon as - and not before - the last holder lets go.

**What Happened**: Lane cdpd1's DOM.setOuterHTML (Blink's DOMPatchSupport) parses the new markup into a fragment and moves the nodes it needs into the page. Each move is an InsertBeforeAction whose inner RemoveChildAction records the fragment node it came from, so undo can put it back - Blink's actions keep those nodes as Members, so the fragment lives as long as the history. Crane's patch ended with `releaseIfUnwrapped(fragment)`, which freed the fragment and its remaining nodes; the history's RefHolds then read null, and DOM.undo failed. The test caught it (setOuterHTML, then undo).

**Fix**: `dom_patch.dropParsed`: an emptied, parentless root goes now (`releaseIfUnwrapped`); one that kept children loses its creator reference only - the rule `dom.mutation.dropConvertedNode` already follows for a converted fragment an error left children in.

**Takeaway**: **Free a scratch tree outright only when it is empty or provably unheld; otherwise end the creator's reference and let the counts free it when the last holder goes.**
