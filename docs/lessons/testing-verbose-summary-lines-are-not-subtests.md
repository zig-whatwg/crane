# Testing: A Verbose Summary Reuses Subtest Markers

**Date**: 2026-10-24
**Lesson**: A verbose WPT log needs section boundaries before its status markers can be treated as individual test results.

**Why**: `ProgressTracker` prints detailed cases and final totals with the same indentation and status icons. The final `Passed`, `Failed`, and `Timeout` totals therefore look like three more cases to a parser that only recognizes the marker prefix.

**What Happened**: While preparing a fresh CSS A/B, a parser sanity check against an archived, reconciled Crane run produced 173 PASS, 17 FAIL, and 1 TIMEOUT instead of 172 PASS and 16 FAIL. It stopped at the failure-report heading but missed the successful shard's `WPT TEST RESULTS` heading, so it attached the three aggregate lines to the last test.

**Fix**: Start detailed capture only at a numbered source/context header, and end it at the box header preceding either summary section. Preserve the variant and each repeated name's occurrence number. Reconcile every source's four status counts with its journal; run Crane fixtures serially when using verbose text as exact-name evidence. The corrected sanity check recovered all 35 sources, 38 context records, and exactly 172 PASS / 16 FAIL.

**Takeaway**: **Recognizing a status icon is not proof that a line is a test case. Parse its section and reconcile its counts.** See also [Crane tests are not in the wptreport stream](testing-crane-tests-are-not-in-the-wptreport-stream.md).
