# Testing: Reading a torn-down node's state in an engine-less realm reads freed memory

**Date**: 2026-10-11
**Lesson**: In a unit test whose realm has no engine and no agent (`ctx.agent == null`), a node its tree tears down has its storage returned at once (Node.deinitNodeByType), so any later read of that node - `stateAs`, its `_internal` - reads freed slab and arena memory, and whether the test passes depends on what the allocator left there.

**Why**: deinitNodeByType releases a torn-down node's storage when no wrapper can own it: `ctx.hasEngine()` false and `ctx.agent == null` means "an engine-less native parser/test context" (a realm with an agent but no engine is a retired page realm, whose storage stays). A freed slab slot's first 8 bytes - the Instance's vtable field - become the free list's next pointer.

**What Happened**: tests/html/object_embed_teardown_test.zig tore a div down and then read its object/embed children's state to see whose deinit ran. With the process-wide slab, the freed slots' "vtable" pointed at another slot of a long-lived, mostly free slab, and `stateAs` found nothing and returned null - the expected answer, by luck. Instances B1 gave the test's runtime a fresh slab of its own; the "vtable" now pointed into a never-issued slot and `stateAs` walked a garbage ancestry slice: SEGV. inst3's blob URL test had a related trap: it lent the page's realm another Browser's scope for one script, and since B1 that script's Blob was allocated in the other scope - freed with it while the page still held the wrapper.

**Fix**: Give the test realm an agent identity (`ctx_data.agent = @ptrCast(&some_byte)`) so the teardown leaves the storage, as a page realm's would, and the scope's end frees it. Never lend a realm another Browser's scope; hand the page what it needs as data instead.

**Takeaway**: **A green test that reads an object after its teardown is reading freed memory unless the teardown is documented to keep it - check which branch of the storage release the test's realm takes.**
