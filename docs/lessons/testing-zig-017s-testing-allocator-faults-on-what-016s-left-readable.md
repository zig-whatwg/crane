# Testing: Zig 0.17's testing allocator faults on what 0.16's left readable

**Date**: 2026-10-31
**Lesson**: Under Zig 0.17, std.testing.allocator is a SafeAllocator that poisons freed memory and guards each allocation with a canary, so a test that passed on 0.16 can crash on 0.17 because it was always wrong.

**Why**: 0.16's DebugAllocator left freed memory readable and had no per-allocation canary, so a use-after-free that read a still-intact old copy, or a write a few words past a small allocation, did nothing anyone could see.

**What Happened**: The port's `zig build test` rounds crashed in three places, and none was a port mistake:
- tests/platform protocol_conformance_test (8 binaries): a `defer platform.abortTransaction(read)` ran after `deleteStore` had freed the store the transaction points into. 0.17 faulted at 0x5555...556d, which is poisoned memory.
- tests/codegen member_unions_test: `Model.init` returned its ArenaAllocator by value, but the IR kept `arena.allocator()`, a pointer into init's dead frame, and allocated through it later. 0.17's arena faulted on the stale state.
- tests/v8 wrapper_cache_gc_test (5 tests): the mock wrapper was one u64 whose first word pointed at itself. The cache arms a V8 weak finalizer on every wrapper, and V8 read that word as the location of a GlobalHandles::Node and wrote its class id, parameter and callback (32 bytes) past the 8-byte allocation. SafeAllocator reported "free of invalid memory ... corrupted metadata".

**Fix**: Fix the test, not the allocator. End the transaction before the delete. Put the arena on the heap so the pointer the IR keeps stays valid. Size the mock to hold a whole handle node (`[8]u64`).

**Takeaway**: **A new crash under 0.17's testing allocator is most likely an old bug becoming visible: read the fault address (0x55... is poisoned memory, "corrupted metadata" means an overrun) before blaming the port.** A mock that an engine API writes into must be as large as the structure the engine thinks it is.
