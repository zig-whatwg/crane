# Testing: A correction for a bug becomes the bug when the bug is fixed

**Date**: 2026-09-29
**Lesson**: `tools/wpt_progress.py` divided every variant file's subtest count
by its variant count to undo a runner bug; the bug was fixed the same day, and
for a week the division undercounted every slice file by its slice count.

**Why**: The division was written against a symptom - every variant run of a
file reported the file's WHOLE set, because `location.search` was `""` in every
top-level test document, so `/common/subset-tests.js` saw no range. 71ffd213a
(2026-09-22 11:42) fixed `location.*`, and from then each slice variant
(`?1-1000`) reported only its slice. Nothing tied the correction to its cause,
so fixing the cause left the correction in place, dividing counts that were
already right: `euckr-encode-href-errors-han.html` reports its 23,097 subtests
once between its 24 slices, and the page counted 962 of them.

**What Happened**: The page printed the evidence for its model live, and the
evidence decayed in plain sight: "the raw sum is about 12x larger" became
"about 2x", and "the division is exact for 250 of 251 multi-variant files"
became "278 of 347, 56 did not divide evenly". The prose around those numbers
stayed as confident as the day it was written ("the variant never reaches
`location.search`"), so a reader saw a caveat, not a refutation. The integrator
queued a runner fix, "pass each variant's query to the page"; a probe page
printing `location.search` under the runner showed `?1-1` on the first try.
Correcting the unit moved the 0.1 page from 167,375 of 452,557 subtests to
739,440 of 1,116,239 (encoding/ alone 51,244 -> 616,935 passing).

**Fix**: No division. Every (source, global, variant) run is its own WPT test
URL, as MANIFEST.json and wpt.fyi count them, and the journal line already sums
them. A run from before `QUERY_REACHES_PAGE` (71ffd213a) still overcounts a
variant file, so its count - kept apart as `_sub_hw_pre` - is divided by the
file's variant count, which is exactly the no-query set; `HW_MODEL` rebuilds
the high-water marks that mixed the two. `declared_variants` also reads
unquoted attributes, which the old regex missed (`<meta name=variant
content="?load fires normally">` in the xhr timeout files).

**Takeaway**: **A correction for a bug must name the bug, so that fixing the bug
retires the correction; and when a model's evidence is printed live, a number
that stops supporting it is a refutation, not a caveat. Before fixing what a
report says is broken, probe it - the queued runner fix was for a bug fixed a
week earlier.**
