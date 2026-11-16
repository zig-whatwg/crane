# Testing: A relative time is zero when it shares a coarse tick with its origin

**Date**: 2026-11-15
**Lesson**: "Greater than 0" does not test that a timing mark was taken. A mark taken within one coarse tick of the time origin reads exactly 0, which is also what an absent mark reads. To assert that a mark exists, put a delay the test controls between the origin and the mark.

**Why**: Resource Timing's "convert fetch timestamp" returns 0 for a zero timestamp and otherwise the relative high resolution coarse time: the moment coarsened (Crane: 125 us), minus the time origin, which is on the same grid. A browser's service worker start is an inter-process hop after its navigation start, so the difference is always milliseconds there. In Crane, HTTP fetch step 3.3 (the service worker start time) runs tens of microseconds after the navigation starts, in the same task.

**What Happened**: crane/flakes2-sw-navigation-timing-order.https.html asserted `entry.workerStart > 0` for a service-worker-controlled frame navigation and failed 4 or 5 runs of 10 on every runner: "expected a number greater than 0 but got 0". A probe that printed the raw values over 310 navigations (iframe insertions and location changes, activating and active workers) showed workerStart was 0 or 0.125 ms and nothing else, about half each. Nothing was missing: the mark was there and equal to the origin at the clock's resolution. The file's own header already said the specs give an order and not a gap, for fetchStart; workerStart against the origin is the same case.

**Fix**:
1. A stable failure fraction near one half with a value of exactly 0 is tick arithmetic, not a race. Print the raw values before reading any code: two values one tick apart settle it.
2. Assert what the spec guarantees: the order with ties allowed (0 <= workerStart <= fetchStart).
3. Where the test must show the mark exists, make the gap certain rather than likely. The file's third navigation reaches the worker's scope through a redirect the server holds for a second (/common/slow-redirect.py?delay=1), so its workerStart, the final service worker start time, is a second past the origin, and `> 0` is safe.
4. Do not move the engine's clock to make such a test pass. Equal is the specified answer.

**Takeaway**: **A fast engine can take two marks in one clock tick, so a zero relative time means "at the origin" as well as "absent". Test presence across a delay the test controls, and test order with ties everywhere else.**
