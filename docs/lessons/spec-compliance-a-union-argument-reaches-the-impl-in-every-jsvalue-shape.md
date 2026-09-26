# Spec Compliance: A union argument reaches the impl in every JSValue shape

**Date**: 2026-09-26
**Lesson**: An impl that takes a raw `runtime.JSValue` for a union receives strings as `.string`, numbers as `.number`, and objects as `.handle`.

**Why**: Two WebSocket functions returned early on anything not a handle, so `new WebSocket(url, "proto")` ignored its protocols and `send("x")` sent an empty frame.

**What Happened**: Silent wrong behaviour rather than an error, on the commonest argument shapes.

**Fix**: Convert every shape the union allows (lane/websockets 64bcf1738, 0fb86da18).

**Takeaway**: **An impl that takes a raw JSValue owns the whole union conversion.**
