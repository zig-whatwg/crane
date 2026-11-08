# Debugging: A quadratic build hides the recursions a deep tree reaches

**Date**: 2026-11-08
**Lesson**: While a deep tree costs O(nodes x depth) to build, pages and probes time out before they reach the code that recurses once per level on it; making the build linear makes those recursions reachable, so a cost fix must come with a probe of every recursion over the tree at the depth the build now allows.

**Why**: A probe that times out says nothing about what would have happened next. Crane's sweep built 30,000- and 100,000-level trees and recorded TIMEOUT for appending, removing and adopting them - and the insert and remove steps' walks over the moved subtree (`setConnectedRecursive`, `tree_helpers.collectShadowIncludingDescendants` behind insert step 7.7 and remove step 14) recursed once per level. They had never run deep enough to overflow, because nothing could build the tree in time.

**What Happened**: Lane crash1 batch 3 made a node's insert under a deep parent O(1) (pre-insertion validity's no-children answer, an exact connected flag, the slot steps' root only when a slot is involved, the observer walk's early-out). Writing the timing test - 150,000 levels appended one at a time, then the detached tree appended to the body and removed again - showed that the append and the removal would now reach the per-level recursions: about 120,000-200,000 frames on an 8 MiB stack in ReleaseSafe, far fewer in a Debug test. The same scan found the recursion behind every caller of getShadowIncludingInclusiveDescendants (custom element upgrade, the style engine, font and resource loading).

**Fix**: One iterative shadow-including preorder walk (`tree_helpers.ShadowIncludingWalk`: a host's shadow root next, then its children, then the nearest following sibling; leaving a shadow root resumes at its host's light children, found through the root's host) serves all of them, in the exact shadow-including tree order the insertion steps observe (`tests/dom/crash1_shadow_including_order_test.zig`). The timing test is the guard for both: a quadratic build times out and a recursive move crashes.

**Takeaway**: **When a fix makes deep structures cheap, the timeouts it removes were standing in front of recursions: probe every per-level walk over the structure at the new reachable depth before calling the work done.**
