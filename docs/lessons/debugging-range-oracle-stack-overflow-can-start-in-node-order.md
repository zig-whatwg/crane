# Debugging: A Range oracle can overflow on contradictory node order

**Date**: 2026-10-11
**Lesson**: Trace the failing test's expected-value computation before replacing a correct native algorithm.

**Why**: WPT's DOM helper computes boundary-point positions using `Node.compareDocumentPosition`. It swaps the points when one node follows the other; that recursion terminates only when node order is antisymmetric.

**What Happened**: `Range-compareBoundaryPoints.html` reported 948 JavaScript stack overflows. Crane's Range implementation already used an iterative tree-order helper and at most one boundary-point swap. Instead, Node's unfinished comparison method returned FOLLOWING in both directions for unrelated nodes in one tree. The WPT oracle repeatedly swapped the same two nodes before calling the Range method. Isolating subtest `1,5,0` reproduced the overflow with just two collapsed ranges in sibling paragraphs.

**Fix**: Pin both comparison directions in a native regression, then implement the complete DOM Node comparison algorithm, including attribute owners and disconnected nodes. Reuse `dom.boundary_points.isFollowing` for its iterative ancestor walk. Keep the WPT oracle in the isolated fixture, then run the full upstream Range file and directory so dependent expected-value calculations are exercised too.

**Takeaway**: **A stack overflow reported by a Range test may be in its oracle; test ordering antisymmetry at the lowest API that oracle calls.**
