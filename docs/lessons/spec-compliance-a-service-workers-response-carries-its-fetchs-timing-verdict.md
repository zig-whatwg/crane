# Spec Compliance: A service worker's response carries its own fetch's timing verdict

**Date**: 2026-10-18
**Lesson**: The client's timing allow check for a service worker's response is the verdict of the WORKER's fetch, so every place that copies or stores that response has to keep its timing allow passed flag.

**Why**: Fetch runs its TAO check only on network responses (HTTP fetch step 4.5). A service worker's response arrives at step 3.5, and main fetch step 19 then sets "timing allow passed" because the client's own flag was never failed. Taken literally, any service worker could launder a cross-origin response's Server-Timing, sizes and network times into the page's resource timing entry. Chrome and Firefox do not let it. Chromium's ServiceWorkerSubresourceLoader passes a synthetic or basic response. A CORS or opaque response passes only when the worker's fetch passed TAO and its `Timing-Allow-Origin` also names the client's origin.

**What Happened**: resource-timing-cross-origin-server-timing.https.html exposed serverTiming for a no-CORS opaque response. Lane sw1-b6 took Chromium's rule in http_fetch.serviceWorkerResponse, and cases 1-7 passed. Then the file failed at "via Cache Storage". Crane's cache record never stored timing_allow_passed, so a response the worker had cached came back as "failed", and its timing was hidden. Chromium's cache_storage.proto keeps the flag. Body sizes needed the same treatment: whatwg/fetch #1556 exposes a CORS response's sizes, but Chrome and Firefox hide them for a service worker's CORS response that failed TAO. That was the integrator's ruling (B), on the user's setHeaderValue precedent.

**Fix**: serviceWorkerResponseTimingAllowed (http_fetch.zig) sets the client's timing allow failed flag. fetch_job.bodyInfoHidden hides the sizes of a service worker's CORS response without TAO. The marker for "a service worker's response" is that it carries a service worker timing info. Cache Storage records, format version 2, keep the flag, and a version 1 record reads it as unset.

**Takeaway**: **When a flag decides what a later reader may see, follow it through every copy and store of the object - a cache that drops it turns "passed" into "failed".**
