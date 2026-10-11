# Architecture: A flag made counted changes every caller - audit them all, and test each by collection

**Date**: 2026-10-10
**Lesson**: When an idempotent keep/release flag becomes a count, every caller written against the flag is wrong in one of two ways: it keeps on every toggle (and now leaks) or releases more than it kept (and now ends another owner's keep). So the change needs a complete caller audit - a grep with no head cut - and each caller balanced with one bool of its own.

**Why**: Refcount step 4 (tmp/plans/refcount-design.md 2.3) made `engine.keepPlatformObjectAlive` counted, WebKit's `m_pendingActivityInstanceCount`. A flag could not carry two owners: a script element's queued task and its fetch both kept it, and the first release ended both (fix-list D15). But 23 files called the pair, and most were written for a flag:
- keep on every toggle: IntersectionObserver (each observe()), MutationObserver (each observe()), media Activity.sync, MessagePort and EventSource syncs, each img update;
- release more than kept: WebSocket (close task and deinit), BroadcastChannel (each close() and deinit), Worker, PerformanceObserver (each disconnect() and deinit), SharedWorker.deinit;
- a subtle one: slot signaling skipped its release when a listener signaled the slot again. Under the flag, both signals were the same keep; under the count, the first membership's keep leaked.

**What Happened**: The first audit cut its grep at 60 lines and found 5 of the 13 callers that needed a fix. `zig build test` found the rest: tests/v8's worker test logged thousands of unmatched releases on MessagePort, because a release at zero is an error log in Debug.

**Fix**:
1. The counted operation: a release with no keep left changes nothing. In Debug it is an error log, fatal in unit tests (decision D9), and it is counted on the realm's wrapper cache (`unmatched_releases`).
2. Each toggling owner keeps a `kept_alive` bool: keep only when it is false, release only when it is true.
3. Each owner gets a script-driven test (tests/html/refcount_pending_activity_owners_test.zig): let the activity begin several times and end, drop everything, collect, and ask a WeakRef whether the object went. A leak fails `deref() === undefined`, and an extra release fails through the error log.
4. A test's listener must reach its target through a global it deletes, never through a closure. A listener closing over its own target keeps the target until refcount step 8 (decision D7), which makes the test red for the wrong reason.

**Takeaway**: **Changing a primitive's counting semantics is a change to every caller: grep them all (no `head`), balance each with its own bool, and prove each one by collecting the object it keeps.**
