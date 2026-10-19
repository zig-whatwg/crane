# Architecture: A response stored at its body's end misses the bodies Fetch drops

**Date**: 2026-10-19
**Lesson**: An HTTP cache that stores a streamed response once its body has ended must store the responses whose body Fetch never reads at their head, or it never stores them at all.

**Why**: A body's end is either "finished" or "cancelled because no reader was left". Fetch leaves some bodies with no reader on purpose: main fetch step 20 sets a null body status's body (101, 103, 204, 205, 304) to null, and HTTP fetch follows a redirect without reading the redirect's body (or hands on an opaque-redirect filtered response, which has none). Their pipes are released at the head, the transfer is cancelled, and a writer waiting for "finished" sees "cancelled" and drops the response.

**What Happened**: Lane httpcache1 stored streamed bodies through an observer on the body's PipeSource (Chromium's HttpCache::Writers sit at the same place), publishing at `finish` and dropping at `fail` or cancellation. Followed redirects were already stored at their head (only-if-cached must follow a cached redirect). The tip runner's fetch/http-cache/status.any.js probe still showed "HTTP cache avoids going to the network if it has a fresh 204 response" failing in Crane only: main fetch had nulled the 204's body, which cancelled the writer. A native test (`a fresh 204 is stored at its head`) reproduced it before the fix.

**Fix**: In the store step, decide "bodiless" at the head - a redirect status with a Location, or a null body status - and publish such a response at once with an empty body; observe the pipe only for a body some reader will consume. src/fetch/cache/transaction.zig `store`.

**Takeaway**: **Before waiting for a body's end, list who reads the body: a body nobody will read never "finishes" - it is cancelled - so store it at its head.**
