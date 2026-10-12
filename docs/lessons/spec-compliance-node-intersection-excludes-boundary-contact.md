# Spec compliance: Node intersection excludes boundary contact

**Date**: 2026-10-11
**Lesson**: Test equality at both boundaries when a DOM algorithm asks for strict before/after ordering.

**Why**: `Range.intersectsNode(node)` compares the node's outer boundary points with the range. A node ending exactly at the range's start, or beginning exactly at its end, does not intersect it. Negating `after` or `before` also accepts `equal` and changes that result.

**What Happened**: A range selecting the first of three sibling spans incorrectly intersected the second span. `Range-intersectsNode-2.html` had no passing subtest. The method checked `beforeEnd != .after and afterStart != .before`, while DOM step 5 requires `beforeEnd == .before and afterStart == .after`. Chrome, Firefox and Safari all pass the upstream case.

**Fix**: Use the two strict comparisons. Test every interval among three sibling boundaries, including collapsed boundary points. Also keep a collapsed point inside a Text node: it still intersects the Text's outer boundary interval, so an early `collapsed` check would be wrong. Parentless same-tree roots and disconnected roots exercise the algorithm's earlier returns.

**Takeaway**: **Boundary contact and containment of an interior point are different cases; pin both instead of substituting a generic empty-range rule.**
