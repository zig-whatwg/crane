# Debugging: The network library's URL is not the response's URL

**Date**: 2026-10-05
**Lesson**: A frame at `/common/blank.html?` reported `location.href` without the `?`, because HTTP-network fetch took the response's URL from curl's "effective URL", and curl re-serializes URLs with its own parser, which drops an empty query.

**Why**: Fetch follows redirects itself (curl is told not to), so the URL curl reports is only curl's spelling of the request's current URL. Main fetch defines the response's URL list as a clone of the request's. Any normalization the transport does to the URL leaks into `document.URL`, `response.url` and `responseURL` if its URL is used.

**What Happened**: navigation-api/navigate-event/cross-window/submit-samedocument-crossorigin.html timed out. The form's action was "helper.html?#foo"; the frame's document URL had become "helper.html". The navigation was therefore not a fragment navigation, so no same-document navigate event fired. Batch 6 had queued it as "the frame's URL seems to lose its empty query".

**Fix**: httpNetworkFetchFinish sets the response URL from `request.currentUrl()` only. tests/fetch/response_url_test.zig fetches `/get?` from the local test server; it was red before.

**Takeaway**: **The URL a library reports back is its re-serialization, not the spec's URL. Take URLs from the request's URL list, which the URL parser wrote, and treat any transport-provided URL as a hint at most.**
