# Architecture: Look for the field before building the table - the generated State already had the direct reference

**Date**: 2026-11-06
**Lesson**: Every generated interface State has carried `own._internal: ?*XImpl.InternalState` from the start. The node types never used it and kept their state in per-Browser hash tables keyed by the instance's address. Removing the hash lookup needed no new storage and no codegen change: only the existing field, an O(1) ancestor lookup, and a slab walk for the one thing the tables also did.

**Why**: Early impls said "due to state hierarchy complexity, internal state is stored in a global registry rather than in the State struct", because a base type's impl could not find its own level inside a derived instance's State. The ancestry table (`VTable.ancestors`, `Instance.stateAs`) fixed that later, but the registries stayed. Each registry also did a second job nobody had named: it was the only list of a type's live states, which the Browser-end teardown sweeps walk to free orphans.

**What Happened**: Lane perf2's batch 2 profile put registry frames (InstanceRegistry get/createIn, the NodeBase bridge, EventTarget's locked map, `Element.dataOf`) at 41.5% of innerHTML set, 30.3% of querySelectorAll, 29.3% of the parser, and 18-20% of createElement and build-tree. The design proposed a new pointer and found the field already there, 8 bytes per level that every node paid and nothing read. The list of live states became a walk of the Browser's slab (`SlabAllocator.forEachLive`, Browser end and tests only). `stateAs` dropped its scan: a type's place in any ancestry is fixed by its own depth, a comptime number. Because the reference now lives in the object, a new object at a freed address gets a zeroed State and can never inherit a dead object's state. Before, that inheritance was a check the registry ran at every registration.

**Fix**:
1. `runtime.OwnState(State, T)` keeps the state in the impl's own `State.own._internal`, with InstanceRegistry's API, so each converted impl changed one line (14 node types plus EventTarget's chained instances).
2. The tables that are enumerated per document while the Browser runs (input, img, script, form, ...) stay: a slab walk there would be O(every object of the Browser).
3. dom.instance_bridge reads a node's NodeBase through a hook Node installs, since src/dom may not read Node's state. That removed the map, its mutex and its cache.
4. Every job of the old table needs a new owner, including the nets. The PRE gate found two:
   - The standalone scope (runtime.initializeRuntime) runs no teardown sweeps. EventTarget's table end had released every entry left, so the table now records its scope and walks the slab at its end.
   - A slot freed without its destruction chain now LEAKS what its OwnState levels own. The registries' exit sweep used to free it silently. Production frees a slot only through `gc.releaseStorage` after the chain, so the only case was a test that freed a slot by hand (image_fetch_detach_test). It now runs the base levels' chain first. A missed teardown is now a leak the leak checks see, not a sweep that hides it.

**Takeaway**: **Before adding a side table or a pointer for per-object state, look at what the object already carries; and before removing a table, name every job it does - a lookup table is often also the only enumeration.**
