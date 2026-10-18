# Workflow: wpt.fyi's search answers 0/0 for browsers it has no aligned run of - read the runs' raw reports

**Date**: 2026-10-18
**Lesson**: `wpt.fyi/api/search?q=<path>&label=master&label=stable` picked runs of mixed labels and
revisions and showed Chrome, Firefox and Safari as 0/0 for every bfcache and NotRestoredReasons file,
which reads as "no browser runs these". The aligned stable runs had them all, with per-subtest
statuses and messages.

**Why**: The search endpoint chooses its runs from the labels given and reports file-level counts
only; a browser with no run matching every label shows 0/0, not "missing". Golden rule 2 needs
SUBTEST results per browser, often with the failure message (PRECONDITION_FAILED versus FAIL is the
whole question for the bfcache files: "Could have been BFCached but actually wasn't").

**What Happened**: Lane bfcache-a needed three answers - do unload listeners block caching, are
timers paused in the cache, do browsers cache a page with an open WebSocket. The search said 0/0;
`/api/runs?label=stable&label=master&product=chrome&product=firefox&product=safari&max-count=1`
gave the three aligned runs (23b0b89b1a), and each run's `raw_results_url` (report.json, ~300 MB)
answered all three: unload listeners cached by Chrome and Safari (Firefox and Edge decline); timers
paused by Firefox and Safari (Chrome fires early); open WebSockets cached by Chrome and Safari.

**Fix**: `curl` each run's raw_results_url into an empty scratch directory, filter it with
`python3 -I` for the paths needed, delete it. The per-run metadata is `/api/runs/<id>`.

**Takeaway**: **For a browser-behaviour ruling, read the aligned stable runs' raw report.json -
subtest status and message per browser - never the search endpoint's file counts.**
