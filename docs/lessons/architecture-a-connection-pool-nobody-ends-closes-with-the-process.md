# Architecture: A connection pool nobody ends closes with the process

**Date**: 2026-09-28
**Lesson**: Crane's HTTP connections live in curl's shared pool, and nothing ever ended the pool. Every connection therefore closed when the process exited: a bare FIN, with no HTTP/2 GOAWAY and no TLS close_notify. A peer that waits for the protocol's own goodbye never hears it.

**Why**: Every transfer attaches to one curl share with `CURL_LOCK_DATA_CONNECT` (`curl_backend.globalInit`), so connections outlive the easy handles that made them. That is the point of the share: reuse. curl shuts a pooled connection down properly only when it closes it itself, and for the share that happens in `curl_share_cleanup`. There, `Curl_cpool_destroy` runs `cpool_discard_conn` -> `Curl_cshutdn_run_once`, and `cf_h2_shutdown` submits the GOAWAY. `globalCleanup` had no caller ("the global state now persists for the application lifetime").

**What Happened**: On 2026-09-28, WPT's h2 server on chat (:9000) had 1,421 threads, nearly all spinning, and 429 sockets in CLOSED. Load reached ~267. Two bugs met:
- wptserve's H2 handler loop tested `recv()`'s bytes with `data == ''`, which is never true on Python 3 (upstream has since fixed it with `b''`). A FIN therefore became `receive_data(b'')` forever; only a GOAWAY ended the loop.
- Every runner process ended its h2 connections with exactly that FIN.

A probe server on :9100 that records each connection's end showed the difference directly:
- c34: `1 request(s), NO GOAWAY, EOF`
- c40: `1 request(s), GOAWAY, then EOF`

**Fix** (c40, 0f4d6d24e):
1. `Browser.init` takes a reference on curl's process-wide state (`fetch.network.globalInit`).
2. At the very end of `Browser.deinit`, after the agent and every instance (WebSocket handles included) are gone, it calls `scheduler.endIdleThreadScheduler()` and then `globalCleanup()`.
3. The reference count means the last holder's cleanup ends the pool. An earlier Browser, or one alive alongside, leaves the pool to the others. A later Browser gets a new one. `tests/fetch/network_lifetime_test.zig` pins this.

A process that crashes still closes with a FIN. That is the server's problem to survive, and the fixed server does.

**Takeaway**: **Anything pooled for reuse needs an owner that ends it. "It lives for the process" means the kernel closes it, and the kernel speaks no protocol.**
