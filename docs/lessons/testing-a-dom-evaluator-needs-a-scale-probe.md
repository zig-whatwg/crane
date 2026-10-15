# Testing: A DOM evaluator needs a scale probe

**Date**: 2026-10-15
**Lesson**: Small fixtures hide linear-scan deduplication and comparison sorts; measure a DOM query engine at thousands of nodes, at two or more sizes, before calling it done.

**Why**: Every correctness fixture for XPath has a handful of nodes, where an O(n^2) merge or an O(n^3) sort costs microseconds. The cost shows only when n grows, and only as a growth RATE: one size proves nothing.

**What Happened**: The XPath engine (Codex row 37) passed all its fixtures and WPT files. The integrator's scratch probe (`crane/zz-xpath-scale-probe.html`, sections of nine divs) then measured `//section | //div` at 1.1 ms for 250 elements, 421 ms for 2,000 and 5,497 ms for 4,000 - about n^3. Four causes (review M2): dedup by a linear scan of the members on every step and union; an insertion sort calling `compareDocumentPosition` (itself O(depth + siblings)) per comparison over O(n^2) inversions; `following`/`preceding` materialising the whole tree per context node; and node-set comparisons recomputing both string-values per pair.

**Fix**: Dedup through a hash set beside the member list. Order a node-set without comparing pairs: mark each member's ancestors, walk each tree once entering only marked subtrees (attributes after their element, separate trees by root address), and skip the sort altogether when the step's shape guarantees order (one context node, or a sorted disjoint set on child/attribute/self/descendant axes - WebKit's `isSorted`/`subtreesAreDisjoint`). Walk `following`/`preceding` directly; compute each string-value once and compare node-sets through a hash set or the extremes. Keep the probe: after the fix the same union took 32.7 ms at 4,000 and 73 ms at 8,000 (about 2.2x per doubling), and `//*` on an 11k-node table 32 ms.

**Takeaway**: **Gate a DOM query engine on its growth rate - time it at doubling sizes up to 10k nodes - because no correctness fixture is large enough to show a quadratic merge or sort.**
