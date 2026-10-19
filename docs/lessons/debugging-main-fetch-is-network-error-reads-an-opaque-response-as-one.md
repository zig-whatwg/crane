# Debugging: Main fetch's isNetworkError reads an opaque filtered response as one

**Date**: 2026-10-18
**Lesson**: `main_fetch.isNetworkError` answers true for `status == 0`, and an opaque filtered response a service worker hands back has status 0, so a step-20 check that starts with it skips every such response.

**Why**: Fetch's step 20 checks run on the internal response. Crane hands most responses through main fetch unfiltered, since the filter is marked and consumers apply it, so `status == 0` has stood in for "network error". A service worker's opaque answer is different: respondWith() hands on a response that is already filtered, its status cleared, and the real one is in `InternalResponse.internal`.

**What Happened**: Lane sw1-b7's CSP response check (CSP 4.1.3) began with `if (isNetworkError(response)) return response;`, like its Mixed Content and MIME neighbours. Its unit test with an opaque worker response from a refused origin stayed `.opaque` ("expected .error, found .opaque"), while the default, basic and CORS variants were blocked. fetch-csp.https.html's "Disallowed scope image resource which was fetched via SW" is exactly that case.

**Fix**: Test the response type for a network error, then the INTERNAL response for the status: `if (response.response_type == .@"error") return response; const internal = response.internal orelse response; if (isNetworkError(internal)) return response;`. Read the URL from the internal response as well. The Mixed Content and MIME/nosniff checks beside it still start with `isNetworkError(response)`, so they skip a worker's opaque response (listed as a follow-up).

**Takeaway**: **A response check in main fetch reads the internal response: an opaque filtered one (a service worker's) has status 0 on the outside, which `isNetworkError` takes for a network error.**

**Status** (2026-10-18, lane sw1-b8): the Mixed Content and MIME/nosniff checks now read the internal response too (`blockedByMixedContent`, `blockedByMime`; tests/fetch/sw1b8_opaque_checks_test.zig). All three step-20 checks start the same way.
