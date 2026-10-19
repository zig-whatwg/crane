# Architecture: A key transfer must preserve its allocator

**Date**: 2026-10-19
**Lesson**: Moving owned bytes between a realm and a Browser supplement also transfers responsibility for using the right allocator to free them.

**Why**: An owned slice identifies its bytes, not their allocator. A realm's allocator and its BrowserScope's allocator are independently supplied. A store that frees every entry with its own allocator cannot blindly adopt a realm allocation, even if the common Window path happens to use the same allocator.

**What Happened**: Permission queries built an owned key, copied it into the Browser's subscription, and freed the temporary. Removing that redundant copy required a consumed-on-success construction argument. Before implementing it, the allocator audit found that the proposed direct transfer silently assumed the realm and store allocators matched. No mismatched free shipped: the design was amended first.

**Fix**: Prefer building the key in the destination allocator. Here the existing origin settings hook returns realm-owned bytes and accepts no destination allocator, so `BrowserStore.listenOwned` compares both allocator `ptr` and `vtable`. Matching allocations move only after registration succeeds. Otherwise it privately copies into store allocation, releases that copy on failure, and frees the original with its incoming allocator only after success. Every stored key still has the store's original allocation lifetime; the entry retains neither an incoming allocator nor a pointer to the caller's ownership slot. The generated constructor nulls that slot only after success, with no subsequent fallible operation.

**Verification**: `tests/html/pm2_permission_key_ownership_test.zig` passes exhaustive allocation failures through construction and both direct registration paths. It checks the same pointer for a move, a different pointer for a copy, readable caller ownership on failure, and leak-free teardown. A real Browser query also verifies matching allocator identities and successful registration, proving that the ordinary Window path saves the allocation. This does not assume that worker realms share the Browser allocator.

**Takeaway**: Preserve the destination's allocator invariant before optimizing away a copy, and prove that the real production path receives the intended optimization.
