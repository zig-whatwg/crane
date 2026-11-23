# Spec Compliance: compareDocumentPosition across trees is consistent per pair, not per tree

**Date**: 2026-11-23
**Lesson**: For nodes in different trees, DOM's compareDocumentPosition returns DISCONNECTED + IMPLEMENTATION_SPECIFIC + PRECEDING or FOLLOWING. Chrome, like Crane, picks the side per pair of nodes, so a test may assert one side per pair and the reverse side for the reverse pair, but never one side for a whole tree.

**Why**: The spec's step 6 says the side is to be "consistent, together" and leaves the choice open. Blink compares the two nodes' addresses, so two nodes of one tree can fall on either side of a node of another tree. Firefox and Safari choose differently from Chrome and from each other. A test that expects every node of tree A to precede every node of tree B tests an implementation's choice, not the spec.

**What Happened**: Lane react1 wrote tests/wpt/crane/react1-compare-disconnected-consistency.html to hunt a one-run observation from React's FragmentRefs tests: IMPLEMENTATION_SPECIFIC without DISCONNECTED. Its first version also asserted that all pairs between two trees take one side. That assertion failed in Chrome 157 and in Crane alike: both order by node. Relaxed to the per-pair invariants (both flags, exactly one side, the reverse pair the other side, the same answer when asked again), it passed in Chrome and passed 50 of 50 runs in Crane. The original observation never came back. The two FragmentRefs tests that assert FOLLOWING across trees are classified follows-spec: the browsers split on the side with no majority, so the spec decides, and Crane meets it.

**Fix**: Assert the bits the spec fixes, plus pair consistency: the reverse pair takes the other side, and asking again gives the same answer. Never assert a tree-wide side. Classify a framework test that expects a particular side as follows-spec, with each browser's side as evidence.

**Takeaway**: **compareDocumentPosition's side across trees is implementation-specific and consistent only per pair: test the flags and the pair, never a tree-wide order.**
