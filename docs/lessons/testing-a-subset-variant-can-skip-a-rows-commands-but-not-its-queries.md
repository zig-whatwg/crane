# Testing: A subset variant can skip a row's commands but not its queries

**Date**: 2026-10-27
**Lesson**: In the WPT editing suites, a data row whose execCommand subtests fall in one `?a-b` variant and whose query subtests fall in the next runs its "after" queries in the second variant on the UNMODIFIED DOM, so a "lost after-query" there can be a mirrored swap, not a regression.

**Why**: `tests/wpt/editing/include/tests.js` `runConformanceTest` runs each `document.execCommand` inside `subsetTest(test, ...)` (common/subset-tests.js counts subtests and runs only those in the variant's range), but it computes the before and after query results OUTSIDE `subsetTest`, and only reports them through it. A row that straddles a variant boundary therefore has its commands skipped in the later variant while its queries still run, and its "after" queries read the same DOM as its "before" queries.

**What Happened**: Lane editing4's A/B lost `queryCommandState("insertunorderedlist") after` for `[defaultparagraphseparator div, insertunorderedlist] "<ul><li>foo<ul><li>b[ar</ul><li>b]az</ul>"` in `insertunorderedlist.html?1001-2000` (base PASS 3/3, tip FAIL 3/3 in isolated pairs). The native test of the same row passed for both separators, and the `p` twin passed in WPT. A scratch Crane page that wrapped `document.execCommand` with a logger showed that in `?1001-2000` only the `p` twin's command ran. Over the same DOM, wpt.fyi showed Chrome and Safari FAIL "state before" and PASS "state after" (their SelectionListState answers false), Firefox the reverse, and the stub base (always false) the same as Chrome. So the tip's lost "after" was paired with a gained "before" in the same row: net zero, a swap.

**Fix**:
1. When a lost name is a query "after" in a `?a-b` variant, check whether the row's execCommand subtests are in the same variant: their names end in `: execCommand(...) return value`. If they are missing from the variant's report, the row straddles the boundary.
2. Confirm with a logger page (copy the suite's HTML into a scratch Crane test, wrap `document.execCommand`, print what ran) or run the variant `?1-last`.
3. Compare the row's "before" and "after" results side by side. In a straddling row they answer the same question, so a lost "after" with a gained "before" is a swap, to be reported as such.

**Takeaway**: **In the editing suites a variant boundary can cut a row between its commands and its queries; a lost after-query there must be compared with the row's before-query before anyone calls it a regression.**
