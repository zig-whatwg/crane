# Architecture: Find an object's Browser from its address, not from its context

**Date**: 2026-10-11
**Lesson**: When per-Browser allocators replace a process-wide one, every free, every side-table lookup and every teardown sweep must find the object's own Browser - and the only reference that is valid on every path is the object's address: make the allocation block say who owns it.

**Why**: Instances B1 gave each Browser (runtime.BrowserScope) its own slab and arena. Allocation is easy - `Instance.init` has the realm (`ctx.browserScope()`). Freeing is not: `Instance.deinit`, the collector's finalizer (`gc.releaseStorage`), the address-keyed side tables (InstanceRegistry, EventTarget's, the instance-to-NodeBase bridge) and the Browser's end-of-life sweeps all start from an instance pointer. Its `ctx` is not usable there: context_manager frees retired ContextData at the agent's end, so a finalizer or sweep that runs after it reads freed memory; some test vehicles carry `ctx = undefined`; and a standalone (test) realm has no scope at all.

**What Happened**: The design (instances-design 4.5) put the slab and arena on the scope and said `Instance.init` allocates from `ctx.browser_scope`. Reading the teardown order (Browser.deinit: sweeps before `destroyAgent`, the scope's end after it; context_manager's `retired` list freed in its deinit) showed that the free side could not follow `ctx`. Slabs became 8 KiB blocks aligned to their size, with a 16-byte header naming the SlabAllocator: `SlabAllocator.ownerOf(inst)` masks the address, `BrowserScope.ofInstance` is `@fieldParentPtr("slab", owner)`. 255 slots per slab instead of 256; the header costs nothing else. It answers for a freed instance too, until its scope ends - which is exactly the lifetime the free paths need. The lifecycle flags then moved into the slot itself (8 bits beside the 56-bit generation), so they too belong to the slot's Browser without a registry.

**Fix**:
1. Allocate from the realm: `ctx.browserScope()` (own scope, a ShadowRealm's principal realm's, else the standalone scope).
2. Free and look up from the address: `BrowserScope.ofInstance(instance)` / `runtime.arenaOf(instance)`.
3. Per-Browser side tables are `BrowserScope.Table`s (enum-tagged, one atomic load to find), so a lookup is address -> slab header -> scope -> table -> map.
4. Contract: only for instances a slab issued. A test that hands such code a stack `runtime.Instance` (or one from a bare `SlabAllocator`, which is in no scope) now crashes; give it a slot from a `BrowserScope`'s slab.

**Takeaway**: **An owner you can only reach through a context dies with the context; put the owner where the object's memory is - an allocation block aligned to its size names its allocator for free.**
