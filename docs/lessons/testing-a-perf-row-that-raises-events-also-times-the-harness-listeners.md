# Testing: A perf row that raises events also times the harness's listeners

**Date**: 2026-11-22
**Lesson**: Before reading a perf row that dispatches events at the window (error, unhandledrejection), check what the harness itself listens for: tests/perf/harness.js posted every error event to the runner with a fetch(), so a reportError row timed thousands of outstanding POSTs, not reportError.

**Why**: The harness logs a page's uncaught errors to the run's log by POSTing each one. A row that reports 5,000 errors per sample started 5,000 fetches per sample, and Crane's connection slots were O(N^2) in waiting transfers (since fixed, 8a28c5514) - the per-sample time grew from 87 to 154 ms and an 11-sample run timed the page out.

**What Happened**: Lane tpc's errors.report row grew per sample in both builds; reportError alone in a plain page was flat at about 2.5 us per call. The growth was the harness's POSTs piling up; that in turn exposed the network scheduler's quadratic slot bookkeeping (a burst of 1,600 fetches to one host took 711 ms). The harness now posts at most 20 error events and the count of the rest (b15d3327e).

**Fix**:
1. A row that dispatches window events: read harness.js's listeners first; cancel or stop the event in the row if the harness would act on each one.
2. A row whose per-sample time grows is a finding: probe the same work outside the harness before trusting either reading.

**Takeaway**: **The harness is part of every row: a row that triggers its listeners measures them too.**
