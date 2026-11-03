# Rules for all of src/

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here; Claude Code loads this file when it reads a file under src/.

## Global state

**Crane runs isolated instances (Browsers) and every worker on their own threads, so state has an
owner: the process, a Browser, a Tab, an agent or a realm** - never a thread, never "whoever got
here first". The model and the rules for new state are in [docs/instances.md](../docs/instances.md);
read it before adding state.

1. **No new `threadlocal` and no new container-level `var`** (function statics included). Put the
   state on the object that owns it, or reach it through the realm you run in.
2. **A hook is installed once, at process start**, from its owner's `installHooks()` - never lazily
   in `init`, never on first use, never by making a throwaway object.
3. **Checked by `zig build lint-global-state`** (part of `zig build test`;
   tools/lint_global_state.zig) as a HARD rule (lane gstate4, 2026-11-03): every container-level
   `var` and `threadlocal` in src/ (function statics included) and every C++ global and
   `thread_local` is one of three things, and anything else fails:
   - **a hook slot** - `var x: Hook(T) = .init(..)`, `Hook` from the hook module
     (`@import("dom").Hook`, `@import("process").Hook` or `.hook.Hook`, `@import("hook.zig").Hook`
     inside src/dom and src/process). Its type is the rule (frozen after the process start): it
     needs no marker and no inventory entry. Never `threadlocal`, never in src/webidl/impls/, never
     its `value`/`overrides` assigned or taken by address - write through `install()`,
     `installing()` or `overrideForTest()`;
   - **reviewed process state** - a container-level `var` or C++ global with a
     `// process-wide: <why>` line directly above it: state that genuinely is one per process.
     Say why it holds with many instances on many threads, and how writes from several threads
     are safe - atomic, lock or init-once (an id counter whose only property is uniqueness, a
     diagnostic count, V8's platform);
   - **reviewed per-thread state** - a `threadlocal` or C++ `thread_local` with a
     `// per-thread: <why>` line directly above it: state whose owner is the thread. Say what
     makes the thread the right scope - a call-stack extent (what runs on this thread's stack
     now), an engine's own thread-local. Rare: a threadlocal is never per instance or per tab.
   A marker on the wrong kind fails, and so does a broken hook slot. `tools/global_state_baseline.txt`
   is the INVENTORY - every variable with its class, which the Crane test runner's digest reads -
   not a debt list: a reviewed variable new to it fails until `-- --update` records it (the
   integrator reviews each at merge), and `-- --update` refuses unmarked and misplaced ones.
   `-- --rename '<old>' '<new>'` records a same-file rename with the same kind, declaration and
   count. Never edit the file by hand. Until lane hookfreeze2 has converted the last registration
   lists, keys the inventory already records may stay unmarked (`recorded_debt_allowed` in the
   tool; the integrator turns it off). Report the total and the tool's `by rule:` line beside the
   engine-boundary total.

## DOM lifetime: reference counting

**Crane's DOM is moving to reference counting** (WebKit's model; the user, 2026-10-09): one model
under V8 and JavaScriptCore. Design: tmp/plans/refcount-design.md; the user's decisions:
tmp/plans/refcount-decisions.md. Until the switch (design step 7), an object that keeps a node for
script holds it through `src/dom/node_holds.zig` or a traced edge, never a bare pointer; a
generation check is only a teardown net. Collected trees are freed in slices from the event loop
(`runtime.gc.DeferredTeardown`), never inside the collector.

- **Checked by `zig build lint-refcount`** (part of `zig build test`; tools/lint_refcount.zig):
  no direct `.parent_node =` writes outside NodeBase's setter, and no counted reference stored in
  node state (back links stay raw). Its baseline only goes down.

## Memory

Three families, three tools:

| Family | Measure with |
|--------|--------------|
| Zig pools (arena, slab, gpa) | `std.testing.allocator`, `gc_bench` columns |
| C++ `Global<T>` handles | `leaks --atExit`, live-handle counters |
| V8's own heap | `v8_Isolate_GetHeapUsage` |

**A leak invisible to (1) is usually (2).** This migration fixed 635,764 leaked
handles while the suite was green throughout.

### Zig side

`defer` at the point of allocation, `errdefer` on error paths, thread the
allocator through the call chain, no global state.

**`ArenaAllocator.free` is a no-op.** An arena serving a hot path is a leak
until teardown, invisible to both `std.testing.allocator` and `mstats()`.

### The C++ seam — where the bugs are

The wrapper heap-allocates a `Global<T>` wherever V8 returns a borrowed
`Local<T>`. Every `v8_*` call returning a pointer allocates, and **the caller
owns it**. One wrong assumption here leaked in ~20 places at once, on the DOM's
hottest paths.

- Returned `*Context` / `*Object` / `*Value`: dispose it, or don't acquire it.
  **Prefer not acquiring** — moving acquisition past the early returns needs no
  proof about what the callee retains.
- Before disposing, **prove** the callee doesn't retain it. Two use-after-frees
  shipped from guessing.
- Gate any "safe to dispose" decision on an **allowlist** predicate whose
  default is the safe answer. Blocklists are wrong by default over an open set
  of types.
