# Spec Compliance: Integrity checks precede response handover

**Date**: 2026-10-16
**Lesson**: A request carrying integrity must retain its response until the full body has been verified, and an opaque filtered body fails immediately.

**Why**: Fetch normally hands a streamed response to its consumer at headers. Main fetch step 23 puts a full-body integrity check before that handover. Checking only the current byte buffer hashes a prefix; checking after handover already exposes untrusted content.

**What Happened**: Crane carried integrity metadata into Fetch but never enforced it. The isolated mismatch regression passed no subtests on the base runner; fetch/api/basic/integrity.sub.any.js had 10 failures. Its async driver handed responses onward at headers, and their pipes could still be open.

**Fix**: For nonempty integrity only, retain the final depth-0 response in FetchJob, force the existing collecting producer (which cannot pause waiting for a reader), and resume after finish or failure. Verify before the existing finish function reports timing or calls process_response. Let the existing job destruction path own cancellation. A filtered opaque or opaque-redirect response has a null body even if Crane retains its internal pipe: reject and release it at headers. Parse metadata without allocating; choose the strongest syntactically accepted algorithm before decoding hashes, then hash once through the platform protocol. A malformed token is ignored; an accepted but undecodable strong hash must not allow fallback to a weaker one.

**Takeaway**: **Put a security check before the operation that exposes its result, and preserve both streaming cancellation and the empty-metadata fast path.**
