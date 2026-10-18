# Spec Compliance: A fetch event shows the hop's URL, not the redirect chain's first

**Date**: 2026-10-17
**Lesson**: The request a service worker's fetch event gets for a redirect hop must have the hop's URL as its URL: copy the request's current URL, not its whole URL list.

**Why**: Fetch's request URL is the first entry of its URL list, and a Request object's `url` getter serializes that. HTTP fetch step 3.1 says "a clone of request" - but a clone of a redirected request carries the whole list, so the worker's `event.request.url` would be the chain's first URL at every hop. Every browser shows the hop: navigation-redirect.https.html checks each worker's intercepted URLs hop by hop, and fetch-event-redirect.https.html agrees.

**What Happened**: Batch 3's `copyRequestForWorker` copied the URL list. That never showed while only a navigation's first hop reached a worker (redirect mode "follow", deviation 14). Batch 4 made frame navigations follow their redirects by hand (redirect mode "manual"), so every hop reached the worker - and a worker that answered `start.html` with `Response.redirect(...)` saw `start.html` again at the next hop, redirected again, and the navigation hit the 20-redirect limit: a network error page, a SecurityError on `frame.contentWindow.location`, and a worker log of 21 `start.html` entries (crane/sw1b4-nav-redirect.https.html). navigation-redirect.https.html timed out at its first SW-generated redirect for the same reason.

**Fix**: `copyRequestForWorker` makes the copy from `request.currentUrl()` alone (src/service_worker/manager.zig). The navigation preload request, a copy of the same, gets the hop's URL too.

**Takeaway**: **A request handed to another party (a service worker, a preload) is the hop being fetched: its URL is the current URL - check what "clone" carries before trusting it to mean that.**
