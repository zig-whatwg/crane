# Testing: Pin an ordering helper on all four tree relations

**Date**: 2026-09-30
**Lesson**: Range's boundary point comparison was right for two points in one node and wrong for every ancestor/descendant pair: it tested "B is following A" where DOM 5.2 says "A is following B", and "B is an ancestor of A" where it says "A is an ancestor of B", and it answered "equal" when A followed B with neither an ancestor of the other.

**Why**: The algorithm has four cases - the same node, A following B, A an ancestor of B, B an ancestor of A - and the swapped conditions cancel out in none of them except the first. The helper returned the position of B relative to A for the ancestor cases, so every caller got the inverse there. setStart/setEnd collapsed ranges that should not collapse, "contained" and "partially contained" were wrong, and deleteContents/extractContents did nothing across two Text nodes.

**What Happened**: MutationObserver-characterData and -childList TIMEOUT: their Range.deleteContents/extractContents tests waited for records that never came, because the range contents algorithms removed nothing. A probe showed the data unchanged and zero records. Reading the helper against the spec found the swap. On main the comparison files were far from green: Range-compareBoundaryPoints 6172/9313, Range-comparePoint 4216/5580, Range-set 9663/10920.

**Fix**: DOM 5.2 as src/dom/boundary_points.zig, generic over a tree adapter (parent, index), with a test per relation on a fake tree - red against a port of the old logic (three of four cases failing), green after. Range calls it through an adapter over the Node interface. The ranges area moved from 32,444 to 37,223 passing subtests in one step; Range-set went to 10920/10920.

**Takeaway**: **A tree-order or position helper needs a test for each relation - same node, following, ancestor, descendant. One that is right for siblings can be exactly inverse for ancestors, and the WPT symptom is a hang somewhere else.**
