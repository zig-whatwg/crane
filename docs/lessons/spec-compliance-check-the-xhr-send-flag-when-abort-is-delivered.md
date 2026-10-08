# Spec Compliance: Check the XHR send flag when abort is delivered

**Date**: 2026-10-08
**Lesson**: A live pending-fetch owner does not imply an in-flight XHR; document cancellation must recheck the send flag when its error task runs.

**Why**: HEAD, null-body, data-URL and network-error responses can dispatch terminal events before their PendingFetch task returns. A listener can call window.stop while that native owner is still registered but the XHR send flag is already unset. A stop from terminal progress can instead queue abort before the response unsets the flag.

**What Happened**: Document abort considered only the native pending/canceled/complete flags. It queued an abort that later replaced a completed response with a network error and dispatched readystatechange(4), abort and loadend again. Six Crane cases reproduce the duplicate sequence, including stop from terminal progress.

**Fix**: Skip completed XHRs when snapshotting document fetches. At delivery, implement XHR "handle errors" step 1 again, returning before releasing response values when the send flag is unset. Keep native pending-owner cleanup independent of whether there are error events left to deliver.

**Takeaway**: **Queue-time eligibility and delivery-time eligibility are separate checks; callbacks can complete a request between them.**
