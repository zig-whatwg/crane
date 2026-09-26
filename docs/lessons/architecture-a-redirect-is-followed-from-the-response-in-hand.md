# Architecture: A redirect is followed from the response in hand

**Date**: 2026-09-22
**Lesson**: `httpRedirectFetch` had no response parameter, so it fetched the
redirecting URL a second time, appended the raw `Location` to the URL list, and
read `response.status` after `response.deinit()`.

**What Happened**: the use-after-free crashed 12 fetch and xhr files; the
duplicate request broke every redirect-count test. Fetch 4.4 step 6 now hands
its response to 4.5, which parses `Location` against the response's URL
(7e5aeee37).

**Takeaway**: **A signature missing the spec's argument means the code is doing
something else. Read what you need before `deinit`.**
