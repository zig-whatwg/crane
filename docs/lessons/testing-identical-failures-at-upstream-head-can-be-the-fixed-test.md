# Testing: Identical failures at upstream head can be the fixed test

**Date**: 2026-11-09
**Lesson**: Before treating a file as "fails identically in all three browsers because of a test bug", check two things. First, the upstream issue's state. Second, the browsers' results on the copy Crane actually runs. A fix merged upstream can make every browser fail the NEW test identically, for a different reason.

**Why**: The test-bug exemption (the user, 2026-11-08) holds only while the upstream bug is open, and only for a file that fails identically in Chrome, Firefox and Safari. Crane's tests/wpt is pinned, but wpt.fyi's newest aligned run is upstream head. When the fix has landed upstream, that run measures the fixed test, while Crane still runs the buggy one. The two can disagree completely.

**What Happened**: Lane flaky7 found that html/cross-origin-embedder-policy/reporting-to-worker-owner.https.html and reporting-to-frame-owner.https.html time out in Crane because the test posts `r.toJSON()`, whose ReportBody is a platform object (DataCloneError). We had filed this as wpt#64870. At wpt.fyi's aligned stable run fea36e49dd, Chrome 157, Firefox 159 and Safari 27.2 all showed 3/9 TIMEOUT for both files, so the brief proposed test-bug exemptions. Lane site1 then found three things:

- wpt#64870 had been CLOSED on 2026-11-07, fixed by wpt#64806 (a WebKit export that makes Report and ReportBody dictionaries, w3c/reporting#284) and wpt#64807.
- fea36e49dd is after that fix. Its identical 3/9 is the FIXED test failing everywhere, because no stable browser ships report dictionaries yet. That is a browser lag behind a newer spec, not a test bug.
- On the OLD test, which Crane's pinned copy still is, the aligned run at 94f58d592d gives Chrome 9/9 OK against Firefox and Safari 3/9 TIMEOUT. That is not identical either.

Neither exemption kind applied. The work that remains is Reports as dictionaries (as WebKit did), which pays off once tests/wpt moves past 585d7b6f39d.

**Fix**:

1. `gh issue view <n> -R web-platform-tests/wpt --json state,comments`: a closed issue ends the exemption before it starts. Read the closing comment for the fixing PRs.
2. Diff Crane's copy of the test and its resources with upstream at the wpt.fyi run's revision (the GitHub contents API at `?ref=<sha>`). If they differ, find the aligned stable run at a revision with Crane's version and read the results there.
3. Compare each browser's per-subtest statuses and messages, not just `<passes>/<total>`. A browser that fails at an earlier step, or one that does not ship the feature, is not failing "identically".
4. Only then write the entry. The tools check its form, including equal counts, but they cannot see an issue's state or which test version a run measured.

**Takeaway**: **A wpt.fyi run measures upstream's test, and Crane runs its pinned copy. Check the upstream issue's state and the browsers' results on Crane's own version before calling a failure a test bug that every browser shares.**
