# Architecture: Tell the collector what a wrapper keeps alive

**Date**: 2026-11-06
**Lesson**: V8 schedules collections by the growth of its own heap. A Crane node wrapper is a few dozen bytes of that heap and keeps a whole native tree alive, so a page that makes and drops trees never triggered a collection.

**Why**: Since refcount step 7, a node's wrapper holds one counted reference, and a detached tree lives until its last wrapper dies. Weak `v8::Global` wrappers die in any collection, scavenges included (V8 7.6+), but a collection runs only when V8's heap grows. A clone loop allocates about 200 B of V8 heap per clone (the root's wrapper) against about 2.5 MB of native nodes. Nothing told V8 about the native bytes. The adapter only read `external_memory()`; nothing ever called `AdjustAmountOfExternalAllocatedMemory`.

**What Happened**: Lane perf1 measured with gc_bench in release, at the page op counts of perf round 0. These workloads kept everything they dropped until a forced collection:
- 650 `cloneNode(true)`: 548,150 nodes, 1.7 GB;
- 260 build-tree: 218,670 nodes;
- 260,000 createElement: 136,580 nodes;
- 39 innerHTML-large / DOMParser / document.write: about 340,000 nodes each.
V8's heap stayed at 5-7 MB used throughout. With `--gc` every row went back to about 10 live instances.

**Fix**: `AgentOptions.external_memory` plus capability `external_memory`. The Browser's DOM is a `runtime.gc.ExternalMemory` on its `BrowserScope`. `dom.instance_bridge` adds each node's slot, state block and NodeBase as the node registers, and subtracts them as it unregisters. The V8 adapter reports the figure's change through `Isolate::AdjustAmountOfExternalAllocatedMemory` at two points: the binding exit that brings the DOM-algorithm depth to zero, and each microtask checkpoint outside a DOM algorithm. It reports in 128 KB steps (V8's own re-check step), and the agent's end takes back what it reported. The report is owed on the agent's deferred teardown queue (`Owed.report`), so the binding exit's existing single check of what the queue owes covers it. A second check of its own had cost +29 instructions per getter round trip; with the owed flag, a getter costs what it did in the base. Precedent: Blink before its unified heap, where `V8GCController::reportDOMMemoryUsageToV8` passed the DOM partition's growth to the same call after every task (Chromium 45). Today Blink's cppgc bytes count against V8's global limit. V8 13.1 starts incremental marking at the low-water mark + 64 MB.

**Trap**: in V8 13.1, `HeapStatistics::external_memory()` is ArrayBuffer backing stores only (api.cc reads `backing_store_bytes()`), so the embedder's reports never appear in it. The first green run's tests read 0 there even though the reports were working. The total V8 actually collects by is the return value of `AdjustAmountOfExternalAllocatedMemory`, and a change of 0 reads it without starting anything (`v8_Isolate_GetExternalMemory`; `engine.heapStatistics`'s `external` now reports it).

**Takeaway**: **A collected handle to a large native graph needs that graph's native bytes reported to the collector. Otherwise the collector judges it by the handle's few bytes and never runs, and "unreachable" never becomes "freed".**
