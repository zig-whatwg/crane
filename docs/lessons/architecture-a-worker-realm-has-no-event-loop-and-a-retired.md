# Architecture: A worker realm has no event loop, and a retired context marks a dead window realm

**Date**: 2026-09-25
**Lesson**: A worker's `ContextData` has `event_loop == null`, and its `timer` is the page's. A window's retired `ContextData` has `engine_ctx == null`, and it is never freed while the context manager lives.

**Why**: Workers run their tasks as timers on the page's loop. `retireEntry` sets `engine_ctx` to null instead of freeing the entry.

**What Happened**: Async `fetch()` (the networking lane, increment 1) holds a promise resolver across turns. For a worker, "queue a task on the realm's event loop" does nothing, so it falls back to a 0 ms timer followed by `finishTaskIn`.

**Fix**: For a window realm, `ctx.engine_ctx != null` is a safe liveness test across turns. A worker realm needs a teardown hook instead, because its isolate may already be disposed.

**Takeaway**: **Before holding a realm across turns, find out who tells you it ended, and whether its isolate outlives that moment.**
