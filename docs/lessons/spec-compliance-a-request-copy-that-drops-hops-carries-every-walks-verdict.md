# Spec Compliance: A request copy that drops hops carries every walk's verdict

**Date**: 2026-10-18
**Lesson**: Crane's service worker copy of a request keeps only the hop's URL, so each Fetch algorithm that walks the URL list needs the dropped hops' verdict carried beside it - and every place the spec resets the URL list must clear those verdicts too.

**Why**: Fetch's request objects go through a service worker with their whole URL list (whatwg/fetch#1321 origin, #1335 URL list): `fetch(event.request)` sends the Origin header, Sec-Fetch-Site and SameSite cookies from the chain. Crane's `copyRequestForWorker` keeps only the current hop, because browsers show the hop's URL as `event.request.url`. Every walk over the list then sees one URL.

**What Happened**: Lane sw1-b5 found the Origin header's walk (redirect-taint) and carried its verdict as `redirect_tainted`. Lane sw1-b7's Fetch Metadata made a second walk, Sec-Fetch-Site, with the same blind spot. "Same-origin with cross-site redirect and passthrough service worker" would have said same-origin where Chrome says cross-site. It got its own carried verdict, `dropped_urls_site`. Then a third trap appeared: the Request constructor's step 13.8 resets the URL list to « current URL » for a non-empty init. Crane's comment said that was "already the default", true for a URL input but false for a clone. So `new Request(event.request, {...})` kept `redirect_tainted`, and navigation-headers' three change-request Origin cases sent "null" where every browser sends the worker's origin. Fixing the reset fixed those, and kept the new verdict from leaking the same way.

**Fix**: `InternalRequest.dropped_urls_site` (a `SiteRelation`, computed in `copyRequestForWorker` against the request's origin, cloned with the request). `Request` constructor step 13.7-8 really resets the URL list and clears `redirect_tainted` and `dropped_urls_site`. Cookies' same-site walk (cookies.zig) is the third reader and is a listed follow-up.

**Takeaway**: **When a copy keeps less of a list than the spec's object, list every algorithm that walks that list and carry each one's verdict - and clear them wherever the spec resets the list.**
