# Architecture: A filter applied in place loses the internal response

**Date**: 2026-10-17
**Lesson**: A filtered response always has an internal response (Fetch), and the user agent reads it where script cannot: a script element's body, a service worker's respondWith(), the Cache API. Crane marked the filter on the response and applied it in place when fetch() made a Response object, which cleared an opaque response's status, headers, URL list and body for good.

**Why**: `InternalResponse.applyFilter` was written for consumers shown only the filtered response (an XMLHttpRequest, a network error), and fetch() reused it for the Response object. For basic and CORS responses that loses only headers script may not see. For an opaque response it loses everything, and nothing complained, because a Response object's script-visible fields are exactly the cleared ones. The internal response is read only when the Response object is handed on: by a service worker to the page it controls, or by a cache to a later match().

**What Happened**: Lane sw1-b3, Handle Fetch. A controlled frame's `<script src=CROSS-ORIGIN>` behind a worker answering `respondWith(fetch(event.request))` fired `error`: respondWith() copied status 0 and no body, and the script element (which reads the unsafe response) got nothing to run. Cache.put() of the same response stored an empty record, so opaque-script.https.html, whose worker answers from caches, TIMEOUT. Without the service worker, the network's response reached the script element directly and the gap never showed.

**Fix**: 5879463672b. `InternalResponse.internal`, the internal response of an opaque or opaque-redirect filtered response. `filter()` moves what the filter hides into it (every allocation first, so a failure moves nothing), then filters; clone() clones it and deinit() frees it. fetch() uses `filter()`; respondWith() copies an opaque response from its internal response; the cache stores the internal response and filters again on match(). crane/sw1b3-opaque-response pins that script still sees status 0, empty headers and URL, a null body.

**Takeaway**: **Clear a response in place only when nothing will ever read it unfiltered again; a Response object can be handed on - to a controlled page, to a cache - and needs its internal response kept.**
