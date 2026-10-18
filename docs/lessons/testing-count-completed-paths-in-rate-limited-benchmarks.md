# Testing: Count completed paths in rate-limited benchmarks

**Date**: 2026-10-18
**Lesson**: Count the events that prove a benchmark reached its intended path; assignment count alone can hide rate limiting.

**Why**: A Location setter parses before navigation's per-context rate limiter. Repeating it thousands of times can measure mostly rejected requests while appearing to exercise complete navigation.

**What Happened**: A cost fixture warmed up with 100 canceled Location.search assignments, then timed 10,000 more in the same context. Its assertion saw only 100 measured navigate events: Crane permits 200 requests per context per ten seconds. The elapsed time included every setter but only 100 complete canceled-navigation paths.

**Fix**: Keep the original smoke log as failed fixture validation. Load 100 same-origin target frames outside the timed interval, warm separate frames, then make 100 canceled assignments per measured frame. Assert that all 10,000 events fired, cancellation took effect, and every target URL stayed unchanged. Compare the same complete path on BASE and tip without changing the limiter.

**Takeaway**: **A workload counter should validate what completed, not merely what was attempted.**
