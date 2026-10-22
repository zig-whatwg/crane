# Testing: Progress floors belong to a test revision

**Date**: 2026-10-20
**Lesson**: Scope remembered subtest totals and best passes to the measured WPT revision, and retain every unexplained per-file pass loss across report regenerations.

**Why**: A high-water mark protects a crashing test from shrinking the denominator. It becomes a phantom failure when an upstream snapshot declares fewer tests. Aggregate pass totals also conceal regressions when another file gains the same number of passes.

**What Happened**: The body/window and frameset/window event-handler files each reported 140 passing subtests after the WPT snapshot changed, but the report retained an old target of 376 each. The state had no revision attached to its accumulated floors. Separately, a generation could lose passes in a file that remained OK without listing the loss. Generation 170 lost one pass in both abort-refresh-immediate and test-performance-attributes while other tests gained passes.

**Fix**:
1. Resolve a journal's labelled Crane commit to its `tests/wpt` gitlink and persist that provenance. Never substitute the current checkout or a timestamp for missing provenance.
2. Merge high-water marks and best passes only within the latest measurement's WPT revision. Keep a same-revision crash's floor, including when the original journal rotates away. Rebuild unscoped legacy marks from available evidence.
3. Compare per-file pass maps, even when aggregate totals and file statuses are unchanged. Record every loss with its generation and both revisions; retain earlier unresolved losses.
4. Require a disposition for the exact file and generation, with three isolated pairs, a dated user ruling, or matching upstream revisions. A repeat or unrelated gain must not clear the publication failure. The explicit override changes the exit status, never the evidence.
5. When migrating history, use only a previous state whose journal identity matches that generation. Disclose missing per-file evidence instead of inventing a baseline from aggregate totals.

**Takeaway**: **A remembered maximum needs the identity of what was measured; a loss needs a durable explanation, not merely another report run.**
