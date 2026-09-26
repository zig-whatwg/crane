# Architecture: A defer that frees `self` runs before the earlier defers that read it

**Date**: 2026-09-25
**Lesson**: Zig runs defers in reverse. `defer self.release()` declared AFTER `defer if (entered) v8_Isolate_Exit(self.isolate)` runs FIRST, so the exit reads `self.isolate` out of freed memory.

**Why**: `Call.settle` (async `fetch()`) entered the realm's isolate when it was not current - always, for a worker's fetch, whose settle task runs on the page's loop - and deferred the exit before deferring the release. On the window path `entered` is false, so the freed read never happened there.

**What Happened**: once worker `fetch()` ran the async `call_fetch` (the workers lane, 9ec30ea8f), four `fetch/` files crashed in their [worker] variants in a full sweep: SEGV at 0x70/0x71 in `Call.settle` under `NativeTimerManager.poll`. The integrator's first theory - a freed worker ContextData - was wrong; the faulting line in every stack was the deferred exit. The networking lane found it by reading the stack's line rather than the theory.

**Fix**: read what the late defers need into locals BEFORE any defer that can free the owner (`const isolate = self.isolate;`). `XMLHttpRequest`'s `PendingFetch.run` and `timedOut` already declared their destroy before their exit. Pinned by `crane/net-fetch-worker-terminate.html` (terminates workers 0-40 ms after starting fetches in them; exit 134 before, clean after).

**Takeaway**: **When a function frees its own receiver in a defer, every other defer that touches the receiver must be declared after it - or read what it needs into a local first. Check the faulting line before the theory.**

## A second case: leave a realm before destroying it (2026-09-26)

The navigation lane met the same ordering: a commit that ran script inside
`JsScope.init(ctx)` also deferred freeing its integration, which destroys that
context. Declared after the scope's defer, it ran first - the context was
disposed while entered, then exited. Fix: put the scope in a callee, so it has
exited before the caller frees anything.
