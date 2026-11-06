# Debugging: One flaky file can hide two causes - log the raw times per condition

**Date**: 2026-11-06
**Lesson**: When a timing file fails only after certain files run before it in the same process, log the raw, uncoarsened times and the transport's own identifiers under each predecessor. Two predecessors with the same 0 can have two different causes, and the fix for one leaves the other.

**Why**: navigation-timing/secure-connection-start-non-zero.https.html asserts secureConnectionStart > 0. Measured on the generation 205 runner (wpt_runner --repeat, a fresh process per run):
- alone: 0/100 failures, and 0/100 with --load=8;
- after navigation-timing/content-encoding.https.html: 100/100;
- after secure-connection-start-reuse.https.html: 88/100.
A diagnostic runner logged curl's CONN_ID and NUM_CONNECTS, its raw phase times, the fetch's start and the navigate() entry. The two predecessors failed for different reasons:
- After content-encoding, the navigation REUSED that file's keep-alive connection. Fetch's "clamp and coarsen connection timing info" step 1 then makes every connection time fetchStart, and Crane's time origin was the fetch's start (HTML "create and initialize a Document object" step 8), so the result was 0.
- After the reuse test, the connection was FRESH (conn 2, one connect of 0.17-0.22 ms). Crane floored curl's microsecond times to whole milliseconds, which made the TLS start equal to the transfer's start, in fetchStart's tick.
A third measurement was the gap from navigate() entry to the fetch's start. The diagnostic read it as 63-100 us, inside Crane's 125 us tick, so a time origin taken at the navigation's start (where Chrome and WebKit take it) passes the reuse case only when the gap crosses a tick. The 63-100 us predicted 17 passes in 30. The fixed runner passed 8. The diagnostic had printed a log line between the two marks, and those writes widened the very interval it measured: log every mark at the end, never in between.

**What Happened**: The queue's hypotheses were three: reuse, truncation, or the time origin. Each had partial support, and the brief warned they disagreed. Earlier notes said "fails only under load" or "passes only after a prefix" because each came from a different predecessor and a different code generation. Measuring each condition separately (step 1) settled that load does not matter and file order does. Logging per condition (step 2) split order into its two mechanisms.

**Fix**: Two fixes in one batch, under one FULL A/B (lane flaky6):
- A, the deterministic case: curl's phase times are carried as fractional ms (src/fetch/network/{backend,curl_backend,connection_pool}.zig, http_fetch connectionTimingInfo). Red tests: a 0.2 ms connect through httpNetworkFetchFinish, and a real loopback connect through the scheduler.
- B, the browser majority: the time origin is the moment HTMLIFrameElement.navigate() is entered, carried on the Navigation record to createNavigationTimingEntry.
B's residual is timing-bound. It is recorded with the new `timing-bound` disposition kind, which carries the tick, the measured gap, the pass rate, the condition and the code paths, and is flagged STALE when those paths change. No delay was added: that would be an invented path.

**Takeaway**: **Measure each condition apart, then log the raw times and the transport's identifiers (connection id, connect count) in each. One file's flake can be two mechanisms - here a reused connection and a truncated fresh one. Fix the deterministic one deterministically. Measure the gap before promising anything about the other, and print nothing between the marks you are timing.**
