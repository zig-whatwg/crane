# Spec Compliance: When removing a serialization, check which spec rule it was quietly satisfying

**Date**: 2026-09-26
**Lesson**: RFC 6455 4.1 step 2 (one connection in CONNECTING state per host and port) held only because the old handshake blocked.

**Why**: Making the handshake parallel removed the serialization, and the rule with it.

**What Happened**: constructor/014 caught it after the transport rework.

**Fix**: At most one handshake in flight per host and port, others queued (lane/websockets 6dc2f6b8d).

**Takeaway**: **When removing a serialization, check which spec rule it was quietly satisfying.**
