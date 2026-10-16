# Testing: Crane tests are not in the wptreport stream

**Date**: 2026-10-16
**Lesson**: The WPT runner leaves `crane/` files out of its wptreport output; their results are only in journal.jsonl (counts) and the console's failure report (subtest names).

**Why**: result_reporter.zig reports upstream tests only ("Crane's own tests (crane/) are not reported"), so a wptreport is a faithful upload for wpt.fyi-style tooling. A script that lists failures from the wptreport stream therefore never sees a Crane test - not when it passes, and not when it fails.

**What Happened**: Lane selectors filtered `journal.shard*.wptreport.jsonl` for files that were not fully passing and read the absence of its new Crane tests as "they pass". They had passed, but a later Crane test that failed 1 of 8 was equally absent; only the journal's `"passed":7,"failed":1` showed it, and only the console report (run without `--quiet`) named the failing subtest.

**Fix**: For crane/ files read `journal*.jsonl` (`passed`/`failed`), and run the file without `--quiet` to see which subtest failed and why.

**Takeaway**: **A wptreport query proves nothing about crane/ files: check their journal records.**
