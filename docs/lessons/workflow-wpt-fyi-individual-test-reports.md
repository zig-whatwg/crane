# Workflow: Download one browser's individual WPT report

**Date**: 2026-10-18
**Lesson**: An aligned wpt.fyi run's results URL also locates individual test reports, so browser comparisons need not download the whole run.

**Why**: Search results give aggregate counts. Equal counts can conceal different failures, and a full raw browser report can be hundreds of megabytes.

**What Happened**: Row 80 needed the actual failures in the Origin, window-opener and Fetch tests. The results API returned an error, but the individual files in the run's public results directory were available. All three browsers scored 17/18 on the blob test: Chrome and Safari returned `invalid` for its invalid Content-Type, while Firefox returned `application/x-unknown-content-type`. The window-removal test's two failing browser totals also represented different stages of the test.

**Fix**:

1. Get aligned stable run IDs from `https://wpt.fyi/api/runs?label=master&label=stable&products=chrome,firefox,safari&aligned=true&max-count=1`.
2. Use those IDs explicitly with `/api/search?run_ids=<ids>&q=<path>`; `products=` does not select the search runs.
3. For each run, remove the trailing `-summary_v2.json.gz` from its `results_url` and append `/` plus the exact test path, including its variant suffix. Do not append `.json` to the path. This recipe was checked for paths without query variants.
4. Read each returned `subtests` entry's `status` and `message`. Keep the browser version, run ID and revision alongside the downloaded evidence.

This worked for the aligned revision `23b0b89b1a472cac446e3c6e75fc7d6254913ef0`, with Chrome run `6244643405824000`, Firefox `6213611998674944` and Safari `6209999629189120`. For example, the Chrome report was at `https://storage.googleapis.com/wptd/23b0b89b1a472cac446e3c6e75fc7d6254913ef0/chrome-155.0.8059.84-linux-22.04-fadd451b21/fetch/api/basic/scheme-blob.sub.any.html`.

**Takeaway**: **Compare individual browser assertions using the run's own results directory; aggregate scores alone do not establish a majority.**
