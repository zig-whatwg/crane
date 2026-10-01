# Instances and tabs

Status: design (2026-10-01), not yet built. The full design, with the inventory of every
process-global and threadlocal variable in src/, was written by the instances lane; this note is
the part every lane needs to know before it adds state.

## The model

| Owner | What it is | What it owns |
|---|---|---|
| **Process** (`crane.Process`) | everything that is the same for every instance and never changes after start-up | the V8 platform and snapshot, curl's global init, immutable tables, every src/dom hook (installed once by `Process.init`, before any instance) |
| **Browser** | one Crane instance: one thread, one window agent (isolate) and event loop, its workers - a WebDriver BiDi "user context" | the web's shared state a browser profile holds: the storage shed (localStorage, IndexedDB, Cache API, buckets), the cookie jar, the HTTP cache and network, the blob URL store, BroadcastChannel delivery, SharedWorker instances, Web Locks, service worker registrations and clients, permissions, the browsing context groups and the tabs; and its runtime allocators and engine registries |
| **Tab** | one top-level traversable | session history, sessionStorage (its traversable storage shed, cloned into a popup that has an opener), the frame clock, visibility and system focus, its frames |
| **Agent** (event loop) | the window agent, or a worker's | the custom element reactions stack, mutation observer state, the timer nesting level, the execution context stack |
| **Realm** | a Window, a WorkerGlobalScope, a ShadowRealm | its map of active timers, animation frame callbacks, module map, fetch group |

A tab the host creates starts a new browsing context group; a popup joins its opener's group,
unless it was opened with noopener. Two Browsers in one process share nothing mutable. In memory by
default; an optional profile directory persists the Browser's stores, one live Browser per
directory.

## Rules for new state

1. **Do not add a `threadlocal` or a container-level `var`.** A threadlocal is per thread, which is
   neither per instance nor per tab: a value installed on one thread is null on the next, and a
   page's state on it is shared with every other page the thread runs (see
   lessons/architecture-a-threadlocal-is-per-thread-not-per-instance-or-tab.md). A process global
   is shared by every instance.
2. **Reach state through the realm you run in**: a platform object's relevant realm is `instance.ctx`;
   a realm will carry its Browser's scope and its Tab's scope. Per-Browser and per-Tab state of a
   subsystem is a supplement of that scope (Blink's `Supplementable`), made on first use and
   destroyed with the scope.
3. **A hook is process-wide and written once**, at process start - never installed lazily by the
   first owner, never per instance.
4. A planned ratchet, `zig build lint-global-state`, will count every process-global and
   threadlocal mutable variable in src/ and only let the count go down.
