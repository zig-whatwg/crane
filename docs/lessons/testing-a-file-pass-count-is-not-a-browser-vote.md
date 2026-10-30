# Testing: A File Pass Count Is Not a Browser Vote

**Date**: 2026-10-29
**Lesson**: Resolve browser agreement by the exact subtest name and failure message, not the file's passing count.

**Why**: A file often tests several independent algorithms. A browser's one failure can concern a different behavior from the assertion Crane fails, so aggregate counts cannot establish a majority or a split.

**What Happened**: The dialog form-submission file passed 8/8 in Chrome and Safari and 7/8 in Firefox. Crane's newly implemented dialog submission failed the final case, which expected a submitter-less form.submit() to clear returnValue. Reading the individual reports showed that all three browsers passed that case. Firefox instead failed the separate absent-value submit-button case, whose newer specification behavior Chrome and Safari already shipped. A repeated three-browser probe then confirmed that submit(), requestSubmit() and requestSubmit(null) all clear a seeded returnValue when there is no submitter. The two behaviors therefore required different applications of Crane's browser rule: follow unanimous browsers for no submitter; follow the newer shipped spec for an actual button without a value attribute.

**Fix**: Fetch each aligned run's individual report, join on the exact subtest name, and preserve its status and message. Check the specification history for that behavior separately. If the test leaves the mechanism ambiguous, probe the neighboring entry points and controls before changing the implementation. Keep any correction in its own failing-test, gate and A/B cycle.

**Takeaway**: **A browser votes on an assertion, not on the number of assertions its file passes.**
