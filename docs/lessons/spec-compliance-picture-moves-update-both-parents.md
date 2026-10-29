# Spec Compliance: Picture moves update both parents

**Date**: 2026-10-27
**Lesson**: A state-preserving move must reselect image sources in both affected picture contexts.

**Why**: HTML's img and source moving steps mention only the old picture ancestor. An img moved into a picture from a div, or a source moved between pictures, also changes which source the new context selects.

**What Happened**: The integrator's three-browser probe (codex-fetchlater Q27) found Chrome 156 and Firefox 158 update the new picture too. Safari 27 did not ship moveBefore and therefore supplied no result. Both shippers also reselect after a source moves behind its img in the same picture. WebKit's HTMLImageElement::movingSteps and HTMLSourceElement::movingSteps at revision 9009501f68d682d9433641b9b926b083ee073b79 implement the same design. The live spec on this date still mentioned only oldAncestor.

**Fix**: For a moved img, update once if either its old or new parent is a picture. For a moved source, update img children in each affected picture, deduplicating a same-parent move. Reject non-elements, foreign namespaces and irrelevant local names before image work. Add native and Crane regressions for all three moves.

**Takeaway**: **A state-preserving move still changes the structural inputs to source selection. Preserve the object; recompute the affected image selection.**

Related history: [whatwg/html#11113](https://github.com/whatwg/html/issues/11113) and [PR #11137](https://github.com/whatwg/html/pull/11137) replaced the old-next-sibling rule with all img children of the picture. They do not settle the new-parent gap. [PR #12144](https://github.com/whatwg/html/pull/12144) clarifies subtree-root arguments. No matching new-parent issue was found or filed during this batch.
