# Spec Compliance: RequestInit refills headers under the final guard

**Date**: 2026-10-14
**Lesson**: A nonempty RequestInit rebuilds the copied header list even when it has no headers member.

**Why**: The constructor's final mode determines its Headers guard. A copy of an input Request's headers was accepted under the input's guard, which can differ from the new request's guard.

**What Happened**: Request construction appended init.headers to the copied list, retaining headers that an explicit empty headers value should remove. When only mode changed to no-cors, the copied list bypassed the new guard and retained non-safelisted headers. Both cases failed Fetch WPT and isolated Crane regressions.

**Fix**: Follow Fetch §5.4 constructor steps 31–33. For a nonempty init, move aside the already-owned copied list and refill a fresh list through Headers append, selecting init.headers when present and otherwise the saved input list. Dispose the saved list on both success and failure. WebKit FetchRequest::initializeWith(FetchRequest&, Init&&) follows the same selection/refill design. Keep the empty-init path and the source Request intact.

**Takeaway**: **Copying input state does not replace validation under the destination object's final settings.**

References: [Fetch constructor](https://fetch.spec.whatwg.org/#dom-request), [WebKit FetchRequest.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/Modules/fetch/FetchRequest.cpp). Regression tests: tests/v8/fa_request_headers_test.zig, crane/fa-request-replace-headers.html and crane/fa-request-no-cors-headers.html.
