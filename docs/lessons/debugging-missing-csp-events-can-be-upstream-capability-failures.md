# Debugging: Missing CSP events can be upstream capability failures

**Date**: 2026-10-14
**Lesson**: Trace the operation that should violate CSP before changing event counts or report delivery.

**Why**: Generated tests often assert both that an operation fails and that its CSP event arrives. A missing capability or policy-bearing request can fail both assertions without a defect in event dispatch.

**What Happened**: The row 31 baseline recorded 1,123 failing CSP subtests. Worklet files accounted for 482: 354 unavailable addModule operations and 128 missing-event assertions. Another 64 missing-event assertions accompanied 64 unexpectedly allowed module-worker static imports. The 45 report-hash failures read reportID=null from unimplemented serverTiming; the existing cookie-ID hash-delivery control passed. The prefetch policy-union control also passed despite upstream timing-dependent failures.

**Fix**: Group assertion pairs by their initiating operation, inspect its policy and reporting inputs, and retain an independent delivery control. Route missing worklets, module-worker loading, and timing data to their owners. Keep per-violation events distinct; a report-upload deduplication test does not authorize suppressing repeated events.

**Takeaway**: **A missing event is an observation, not a diagnosis; prove that the operation reached the relevant CSP check.**
