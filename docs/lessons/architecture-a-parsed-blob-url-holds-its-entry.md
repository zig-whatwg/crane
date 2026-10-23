# Architecture: A parsed blob URL holds its entry

**Date**: 2026-10-21
**Lesson**: Revocation removes a blob URL from the store; it does not invalidate an entry already captured by a parsed URL or request.

**Why**: Looking up the string again at fetch time substitutes current registry membership for the URL record that the algorithm already resolved.

**What Happened**: Request construction and XHR.open accepted a blob URL, but revoking it before fetch or send made their later lookup fail. A list of importScripts URLs also needs all entries captured before the first script can revoke a later URL.

**Fix**: Give the immutable entry its own reference count and retain its payload once. The store, parsed URL, request and request clones each own the references they keep. Capture under the store lock; authorize access using the request's storage key when reading the captured entry. Distinguish a known missing capture from an older path that has not captured an entry, so a failed capture never falls back to a later registry lookup. Test revoke, clone, teardown and cross-partition rejection under a leak-checking allocator.

**Takeaway**: **Hold the object the algorithm resolved, rather than resolving its name again later.**
