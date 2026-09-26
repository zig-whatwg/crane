# Testing: A subtest total is a count of RESULTS until you divide the fan-out out

**Date**: 2026-09-22
**Lesson**: Summing `passed+failed+timed_out+notrun` over the journal counts each
variant-partitioned file's subtests once PER VARIANT, not once.

**Why**: The runner executes a file once per implemented global **times** once per
declared `<meta name="variant">`, and `FileTally.add` sums every one of those runs
into a single journal line - by design, because a variant is not a resumable unit.
Separately, the variant never reaches `location.search`, so
`/common/subset-tests.js` computes `subTestStart=0, subTestEnd=Infinity` and
`subsetTest` registers EVERY test instead of the slice the variant names. The two
combine: a 24-variant file reports 24 tallies of its whole set.

**What Happened**: asked for "how many subtests are we targeting", the naive sum
gave **3,298,886**. The honest figure is **272,851** - 12x smaller. 25 files of
4,323 held 98.6% of the raw number, all of them `encoding/legacy-mb-*` codepoint
sweeps: `euckr-encode-href-errors-han.html` declares 23,097 subtests and reports
554,328, which is 23,097 x 24 exactly. A "% passing" built on that denominator
would have been 99% governed by 25 files, and one fix to one of them would have
swung it 17 points.

**Fix**: divide the reported total by the variant count. Variants *partition* a
file's subtests - `?1-1000` plus `?1001-2000` is one set split in two - so they
must not multiply it; globals DO multiply it, since `foo.any.html` and
`foo.any.worker.html` are separate URLs in MANIFEST.json with separate results.
The check that this is right rather than plausible: the division comes out EXACT
for **250 of the 251** multi-variant files that have reported anything, including
all 104 partial ones. `tools/wpt_progress.py:subtest_model` does it and the
report states the composition on the page.

**Two things this also means**, neither fixed here:

* Every variant-partitioned file is doing its whole sweep N times. That is why
  `euckr-encode-href-errors-han.html` charges 2,615s of wall time, and it is a
  plausible contributor to the ~1,090 TIMEOUTs.
* `location.search` is empty inside a test document. `Location.get_search` is
  correct, so the document URL is being set without its query - which silently
  disables every test that filters on its own variant, not just the subset ones.

**Takeaway**: **Before a tally becomes a denominator, ask how many times the thing
was counted. A sum over runs is a count of RESULTS; a denominator needs a count of
THINGS, and the ratio between them was 12x here with a green report either way.**
