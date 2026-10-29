# Testing: QuotaExceededError needs its dedicated WPT assertion

**Date**: 2026-10-28
**Lesson**: Use assert_throws_quotaexceedederror for QuotaExceededError; an unsupported assertion form is not valid failing evidence for the product.

**Why**: The pinned WPT testharness treats QuotaExceededError separately from the DOMException names accepted by assert_throws_dom. Its dedicated helper checks the exception's class, code, name, requested value and quota. A test-harness error can therefore persist after the feature is correct.

**What Happened**: Three FetchLater policy fixtures used assert_throws_dom with QuotaExceededError. On a diagnostic build they failed with an unrecognized-exception-name message, while report-only policy delivery and both result-GC tests passed. The assertion called fetchLater, but its own invalid form prevented the intended exception check. The earlier failing results were explicitly withdrawn as behavior evidence (codex-fetchlater Q59).

**Fix**: Read the complete helper in the pinned resources/testharness.js. Archive the old fixture bytes and hashes, then change only the assertion to assert_throws_quotaexceedederror, preserving the call and reporting expectations. These denied-policy cases require a positive integral requested byte count and quota zero. Regenerate the fixture manifests and run the corrected cases against the same BASE and TIP: all three fail on BASE's NotSupportedError and pass on the diagnostic TIP. The final frozen-tree run also passed all three corrected fixtures, with all 80 Crane assertions passing.

**Takeaway**: **Check what the harness actually asserts, and replace invalid failing evidence with a fresh BASE/TIP comparison.** Never change product exceptions to satisfy a malformed assertion.
