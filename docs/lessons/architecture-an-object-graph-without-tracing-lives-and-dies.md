# Architecture: An object graph without tracing lives and dies as a unit

**Date**: 2026-09-22
**Lesson**: The wrapper cache frees an instance when V8 collects its wrapper
unless `engineOwns()` says the engine still holds it. Graphs linked by Zig
pointers - a stream and its controller and writer, a promise reaction's context
- are invisible to V8, so collecting one wrapper freed an object its siblings
still pointed at.

**What Happened**: the writable-streams directory crashed 11 of 11. The fix
(c3138bb64) adds the three WritableStream classes to `engineOwns` as an
ALLOWLIST, pinned by `tests/v8/wrapper_cache_gc_test.zig`. Adding the old
ReadableStream classes the same way exposed their own teardown double-dispose
(`Check failed: node->IsInUse()`), so they stay out until that code is rebuilt.

**Takeaway**: **Only allowlist a class whose own teardown touches nothing but
its own slots.** Holding a wrapper strongly moves its free to teardown, and
teardown code that was never reached before will run.
