# Testing: A browser-majority claim is checked by the failing assertion, on the fork's own WPT revision

**Date**: 2026-11-18
**Lesson**: Before a file is listed as `follows-majority`, compare Crane with each browser subtest by subtest, on the aligned wpt.fyi runs at the revision in `tests/wpt/.crane-upstream-revision`: the same status AND the same failing assertion. A matching pass count is not enough.

**Why**: Lane notes often record a candidate as "Crane = Chrome = Firefox" or "the majority fails too". Many of those notes compared pass counts (0/1 against 0/1), or a browser's result at another WPT revision. Two runs that both fail can fail for different reasons. A browser that fails at another step is not doing what Crane does, so it is no evidence that Crane's result is the correct one.

**What Happened**: Lane gate1 checked 46 candidates that lanes had recorded, against generation 229 and the stable runs at 2358bd4835 (the fork's upstream revision, not the 6bdc2d37fd runs some lanes used). 32 held. 14 did not, and each one still blocks:
- `reload_document_write_onload` failed in all three browsers, but they record 4 entries and Crane records 6.
- `nested-unload-timing` failed in Chrome and Safari with "got 0", and in Crane with "got 506.25".
- `multiple-headers-one-invalid` failed in Crane on geometry before it reached the referrer check that Firefox and Safari fail.
- `promise-resolution-order` timed out in Crane and Firefox, but Safari failed an assertion, so only one browser matched.
- In `element-ready-check-containing-iframe`, Safari rejects with InvalidStateError where Crane and Firefox reject with TypeError. The outcome (the request is denied) is the same, so the entry stands and its `why` notes the difference.

**Fix**: Use a scratch script (tmp/gate1/compare.py, msgs.py, render.py in the lane's evidence):
1. Read Crane's per-subtest status and message from the generation's `journal.wptreport.jsonl`. Match test URLs, not sources: `.window.js` becomes `.window.html`.
2. Fetch each browser's per-test JSON from `storage.googleapis.com/wptd/<full sha>/<run dir>/<test>`. Take the run ids from `wpt.fyi/api/runs?sha=<short sha>&label=stable`.
3. For each subtest, compare the status and the message. Engine-specific error text (the wording of a SecurityError) can be ignored. A different assertion cannot.
4. Take `<passes>/<total>` from the run's `summary_v2.json.gz`. Despite its name, it is served as plain JSON, keyed by test URL, `{"s": status, "c": [passes, total]}`.

**Takeaway**: **"The browsers fail it too" is a claim about each failing assertion, made on the WPT revision Crane runs. Check every subtest's status and message before you write `matches`.**
