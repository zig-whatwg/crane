# Architecture: A kept page runs only store steps at unload - the cleanup steps run when it is destroyed

**Date**: 2026-10-19
**Lesson**: HTML runs every "unloading document cleanup step" at every unload, salvageable or not, but
Crane's installed steps (dom.unloading_cleanup) END the environment: custom element registry cleared,
message ports disentangled, blob URLs revoked, workers terminated, listeners' realm entries released.
Run on a page the back/forward cache keeps, they break it after its restore.

**Why**: The steps were written, and tested, for documents that are destroyed right after: until phase B
of the back/forward cache every unload was followed by "destroy". "Unload" and "destroy" were the same
moment, so nothing distinguished a step that belongs to leaving from one that belongs to ending.

**What Happened**: Lane bfcache-b listed the 14 installed steps before keeping any page. Only WebSocket's
(make disappear) and Web Locks' (record "lock") are about leaving; the rest end what a restored page needs.
Blink runs the equivalent at ExecutionContext::ContextDestroyed - when the document is destroyed, never
when it is frozen into the cache - and WebKit keeps the page's objects alive in its CachedFrame.

**Fix**: A kept document's unload step 18 runs only the STORE steps (dom.bfcache.installStoreStep:
WebSocket fails an open socket and queues its close on the document). The full cleanup steps run when
the cached document is destroyed (its realm's end, at eviction). What would keep a page out is asked
BEFORE pagehide (dom.bfcache.installBlocker: a held lock, a worker, an RTCPeerConnection), so pagehide's
persisted is right.

**Takeaway**: **When a lifecycle gains a state between two steps that used to coincide, re-read every
hook that ran at both: decide for each whether it belongs to the leaving or to the end.**
