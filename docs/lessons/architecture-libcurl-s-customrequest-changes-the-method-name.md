# Architecture: libcurl's CUSTOMREQUEST changes the method NAME, not the transfer

**Date**: 2026-09-22
**Lesson**: A HEAD sent as `CURLOPT_CUSTOMREQUEST "HEAD"` waits for the body
its Content-Length announces; `CURLOPT_NOBODY` is how libcurl makes a HEAD.

**What Happened**: `wpt serve` keeps connections open, so every HEAD blocked
forever in `curl_easy_perform` until the stall watchdog killed the child - a
TIMEOUT journalled with 0 ms of wall time. Fixed in `curl_backend.zig` and
`connection_pool.zig` (0e15612d4).

**Takeaway**: **A TIMEOUT with 0 ms wall time is the stall watchdog: the whole
process was stuck, usually in a blocking C call.**
