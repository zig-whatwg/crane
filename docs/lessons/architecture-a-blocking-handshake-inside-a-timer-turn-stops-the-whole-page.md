# Architecture: A blocking handshake inside a timer turn stops the whole page

**Date**: 2026-09-26
**Lesson**: `curl_easy_perform` on a CONNECT_ONLY handle blocks until the handshake finishes, so a stalling server froze the event loop.

**Why**: The WebSocket handshake happens "in parallel"; the only parallelism a single-threaded engine has is advancing work a non-blocking step per turn.

**What Happened**: One slow server stalled every timer, event and fetch on the page.

**Fix**: Drive the handshake on a per-connection curl multi handle, which curl requires to stay attached for the connection's life (lane/websockets 2bb83ac96).

**Takeaway**: **Anything "in parallel" must advance one non-blocking step per turn.**
