# Architecture: A lazy per-scope resource takes its own lock, not the scope's

**Date**: 2026-11-23
**Lesson**: When a scope starts a resource lazily at its first use (a Browser heap reserved at the scope's first object), guard that start with a mutex of its own - never the scope's general lock - because the first use can come from code that already holds the general lock.

**Why**: `BrowserScope.of(T)` holds the scope's `mutex` across a supplement's `init`. A supplement whose `init` makes a platform object reaches `Instance.init` -> the slab -> `heapEngine()`; had the heap's lazy start locked `mutex` too, that thread would wait for itself (std.Io.Mutex is not recursive) - a deadlock only a unit-test scope (whose heap starts lazily) would ever hit, since a Browser reserves its heap explicitly at its start.

**What Happened**: Lane hard1 (allocator hardening batch A) gave every BrowserScope a span engine; Browser.init reserves it explicitly, and every other scope (203 test sites, the standalone scope) at its first object. The first draft took `scope.mutex` in `startHeapLazily`; review of the call graph (supplement init -> object -> heap) moved it to `heap_mutex` before any test ran.

**Fix**: A dedicated `heap_mutex` for `reserveHeap` and the lazy path; the published engine pointer is an atomic with a release store, so every later `heapEngine()` is one acquire load and takes no lock.

**Takeaway**: **A lazily started part of an owner gets its own lock: the owner's lock may already be held by the caller that triggers the start.**
