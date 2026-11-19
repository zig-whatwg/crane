# Workflow: Rank majority-pass targets from the browsers' raw reports

**Date**: 2026-11-19
**Lesson**: A list of subtests that Chrome, Firefox and Safari pass and Crane fails comes from joining Crane's `journal.wptreport.jsonl` with the three aligned runs' raw `report.json` files, subtest by subtest - a few minutes of work, not a crawl of per-test results.

**Why**: Crane's own failure counts say nothing about what is winnable: lane mime1 found that all 1,734 mimesniff failures also fail in every browser. Per-test fetches (`storage.googleapis.com/wptd/<sha>/<run>/<test>`) cost one request per test per browser, which is too slow for the whole worklist.

**What Happened**: Lane maj1 needed the whole worklist's majority-pass targets in under an hour. `https://wpt.fyi/api/runs/<id>` names each run's `raw_results_url`. That is a full wptreport of about 18 MB gzip per browser at revision 2358bd4835 (fetch it with `Accept-Encoding: gzip`). A 60-line Python join over Crane's generation journal ran in 25 s (`tmp/plans/maj1-evidence/targets.py`). It found 3,524 subtests at generation 231 outside editing/run and referrer-policy, about 980 of them geometry. A second script grouped the rows by cause from path and message (`causes.py`). The top causes did not match the raw failing-subtest volume: MathML handlers, view-transition selectors, missing SVG/MathML longhands, URL setters. Several crossed many files: one missing longhand set hid 221 subtests across 7 files, because the animation-types tests silently skip unsupported properties, which shows up as missing subtests rather than failures.

**Fix**:
1. `curl -H 'Accept-Encoding: gzip' -o <browser>.json.gz <raw_results_url>` for the three aligned runs. Put them in `tmp/<lane>/fyi/` and delete them when done.
2. Join on test id plus subtest name. Keep the rows where at least 2 of 3 browsers PASS and Crane is not PASS. Count a subtest Crane never reported (its file errored, or it skipped the subtest) as a failure.
3. Group by message and path. Read a sample of each group before calling it a cause. Drop geometry ("expected 0px but got 10%" on resolved insets, track lists, origins).
4. `fyi_dump.py <regex> --subtests` answers "what do the browsers do" for a whole family at once, including tests outside the worklist (svg/*/parsing).

**Takeaway**: **Rank by the browsers' raw reports joined subtest by subtest - never by Crane's failure counts - and treat Crane's missing subtests as failures.**
