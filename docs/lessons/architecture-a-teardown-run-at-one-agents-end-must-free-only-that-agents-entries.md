# Architecture: A teardown run at one agent's end must free only that agent's entries

**Date**: 2026-10-04
**Lesson**: `context_manager.deinit` runs at each thread's host agent's end, and it swept process-wide registries - Intl's nine (`intl_binding.deinitAllRegistries`) and ObservableArray's (`observable_array.cleanupAll`) - freeing every entry in them. ShadowRealm's one process-wide record was overwritten by every `createAgent` and cleared by every host agent's end. Each was right only while one host agent existed per process.

**Why**: A worker on a thread of its own (docs/instances.md, "Decisions") is made with no isolate entered on its thread, so the adapter records it as that thread's host agent (`AgentRecord.host_agent`), and its end runs the thread teardown (`isolate_lifecycle.cleanupAll` -> `context_manager.deinit`). Every process-wide sweep in that teardown then frees the page's Intl objects, observable arrays and ShadowRealms while the page still uses them - a use-after-free on another thread, at a moment that has nothing to do with the page.

**What Happened**: Phase A of the worker-threads work (workers lane, batch 1A) wrote a tests/v8 test: two agents on two threads, each making worker realms and churning events, URLs, ports, Blobs, Intl and an async iterator. At base it died first in a `std.HashMap`'s pointer-stability check (EventTarget's registry, put from two threads) - Debug's `SafetyLock` turns concurrent map mutation into an immediate panic rather than silent corruption. Auditing everything the test reaches turned up the sweeps: none of them would show in a single-threaded run, because there the only host agent's end is the process's end.

**Fix**:
1. Tag each entry with the isolate that made it, at the point it is registered (`v8_Isolate_GetCurrent()` inside `register`/`add`, so no call site changes).
2. The teardown frees the current isolate's entries only (`deinitFor(isolate)`; ObservableArray's `cleanupAll` filters on `state.isolate`).
3. Per-agent data that V8 hands no context for (ShadowRealm's callback data) lives on the agent's record and is found from the isolate the callback runs on.
4. Write-once tables (`isolate_lifecycle`'s handlers) are filled at engine start, not by every `createAgent`.

**Takeaway**: **A cleanup that runs at one agent's end must free only that agent's entries - tag each entry with its isolate when it is made. And a two-thread stress test in Debug is a cheap race detector: std's hash maps panic at the first concurrent mutation.**
