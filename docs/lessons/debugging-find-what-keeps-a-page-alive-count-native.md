# Debugging: Find what keeps a page alive: count native contexts, snapshot, attribute handles by site

## Find what keeps a page alive with a heap snapshot, then attribute the handles by site

**Date**: 2026-09-25
**Lesson**: `wpt_runner` journals `heap_used_kb` for every file. `CRANE_HEAP_GC=1` runs a full collection before each reading. `CRANE_HEAP_SNAPSHOT=<path>` writes a DevTools heap snapshot after each file. Together they separate a leak from uncollected garbage, and they show who holds it.

**What Happened**: 11 of the 18 crashes in a full sweep were V8 `FatalProcessOutOfMemory`. With forced GC the heap still climbed about 2.5 MB per file, one whole page. The snapshot showed every old NativeContext reachable directly from "(Global handles)", held by 34 context handles on average. Grouping the "(Global handles)" children by target type turned up more retainers of other kinds: 740 `WindowProperties` holders, 152 global proxies, 1,029 closures, bound `Script`s. Any single one keeps its page.

**Fix**: attribute live handles by creation site. That was a scratch patch that recorded `__builtin_return_address(0)` in an always-inline `trackHandle`, erased the entry at every `delete`, dumped the survivors, and resolved them with `atos -l <image base>`. The top sites were `GetCurrentContext` taken before early returns in interceptors, `v8_Context_Global` and `getHolder()` results never disposed, `evaluateScript`'s bound script (the runner evaluates one per harness poll), realm intrinsics nobody released, and the NewTarget fallback. Two traps along the way:

* **Ownership belongs to the conversion.** `conv.toV8Value(JSValue, ...)` hands back the wrapper cache's own handle for an element. Disposing it freed the cache's entry and crashed the next named access. Release only what you can prove is a copy.
* **An owner whose `deinit` never runs owns nothing.** EventTarget's teardown deliberately skips disposing listener callbacks (its comment blames old handle corruption), so every page with a listener stays alive regardless of the fixes above. The heap does not drop until the LAST retainer per page is gone.

**Takeaway**: **A leaked page is held by its least-cared-for handle.** Counting handles says little; the snapshot's retaining path says which, and the heap reading says whether the last one is gone.

## Count native contexts, then name the first hop

**Date**: 2026-09-25
**Lesson**: `native_contexts` in the journal (V8's `number_of_native_contexts`, read after each file) is the exact measure of page retention. Retained heap only estimates it. A finished page should leave none of its realms behind.

**What Happened**: 40 frame-heavy files in one process went from 4 to 102 live contexts and from 8 to 159 MB after GC. Disposing a retired entry's own context handle alone changed nothing, because every frame was pinned several times over. The fix took four rounds, each named by a heap snapshot's first hop from "(Global handles)" (`tmp/scratch/firsthop.py`-style: BFS from the root, skipping weak edges):

1. `closure Window` - both child-context paths leaked the `Window` constructor and `Window.prototype` they read to fix the global's prototype.
2. `closure TypeError` / `Object` - `destroyChildContext` freed the realm without `disposeIntrinsics`.
3. `object WindowProperties` - which was the frame's **global proxy**, not WindowProperties: a snapshot names an object by the `Symbol.toStringTag` on its chain, and WindowProperties carries that tag. `createChildContext`'s own `v8_Context_Global` result was never disposed.
4. The on* handler values: `EventTarget`'s event handler map never disposed a replaced, cleared or torn-down value. A value is a function in its page, and the page stayed alive.

After all four: 5-7 contexts and ~12 MB, flat across the same files.

**Fix**: to find the holders, run the Global-creation-site tracker (`tmp/scratch/diag_patch.py`), then resolve each growing site to a LINE. `dsymutil zig-out/bin/wpt_runner -o x.dSYM` takes two seconds, after which `atos -o x.dSYM/Contents/Resources/DWARF/wpt_runner -l <base> <pcs>` prints `file.zig:line`. `lldb` over ssh prints nothing.

**Takeaway**: **Every owned handle to anything in a page pins the whole page, and a page is released only when the last one goes.** Fixing one holder moves nothing, so measure the count after each round, not the heap after all of them.
