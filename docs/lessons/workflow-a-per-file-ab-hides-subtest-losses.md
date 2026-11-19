# Workflow: A per-file A/B hides subtest losses

**Date**: 2026-11-19
**Lesson**: A file can lose subtests and gain more in the same run, so its passing count still goes up. An A/B that compares per-file counts (the lanes' `abcmp.py`: `CHANGED <file> base N -> tip M`) reports "0 losses" while the tip loses subtests. Compare subtest by subtest as well.

**Why**: The lanes' window scripts call a FULL A/B loss-free when no file's passing count drops (abcmp.py). That is a file-level comparison. Selector, parser and IDL changes routinely move many subtests of one file in both directions.

**What Happened**: Lane maj1's batch 2 FULL A/B against generation 232 read 1,900,052 -> 1,900,254 (+202), "0 losses". A subtest-by-subtest diff of the two `*wptreport*.jsonl` streams (generation 232's `full/chunks`, the window's `ab/tip/chunks`) found 209 gained and 7 lost: `::part(foo)::first-line` and `::first-letter` (parse-part.html), `::part(my-part)::selection` and its three highlight siblings (highlight-pseudos.html), and `::part(my-part)::highlight(foo)` (css-highlight-api/highlight-pseudo-parsing.html). A new chaining rule that refuses those pseudo-elements after `::slotted()` had also been applied to `::part()`, which takes them. The same check on batch 1 found 461 gained and 0 lost.

**Fix**:
1. After every A/B, diff the subtests of each test in both runs' wptreport streams. Count PASS -> not PASS as a loss, not-PASS -> PASS as a gain, and a subtest only the tip has, PASS, as a gain. Lane maj1's `.maj1/subloss.py` does this in a few seconds on server1; its window's `ab` step runs it beside abcmp.py and prints `subtests lost N gained M` and each LOST line.
2. Report the subtest-level numbers in the merge report next to the per-file ones. A lost subtest goes to "main" like a lost file.
3. When writing a rule that narrows a grammar, list the neighbouring forms it must not touch as cases in the native test (here: what `::part()` still takes).

**Takeaway**: **"0 losses" means 0 subtests lost: diff the wptreport streams subtest by subtest, never only the per-file passing counts.**
