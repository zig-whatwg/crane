//! The slab stamps a generation on every slot it issues, so a holder that
//! recorded the value at acquisition can tell whether an address still means
//! its Instance. The address alone cannot: the slab recycles it, and a
//! same-type newcomer whose state block was recycled too matches by vtable
//! and by state. See AGENTS.md, "A stale weak callback's `Registry.remove`
//! evicts the LIVE entry at a recycled address".
//!
//! This lives under tests/runtime/ because `src/runtime/root.zig` is a module
//! root, never a test root: a `test` block inside `slab_allocator.zig` is never
//! compiled by `zig build test`.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const SlabAllocator = runtime.SlabAllocator;
const Instance = runtime.Instance;
const VTable = runtime.VTable;

const delegates = .{};
const vtable = VTable{
    .name = "SlabGenerationTest",
    .deinit = null,
    .methods_ptr = &delegates,
};

test "a slot reads dead until issued, and dead again once freed" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();
    const slab = SlabAllocator.get();

    const inst = try slab.alloc(&vtable);
    try testing.expect(SlabAllocator.generationOf(inst) != SlabAllocator.dead_generation);

    slab.free(inst);
    try testing.expectEqual(SlabAllocator.dead_generation, SlabAllocator.generationOf(inst));
}

test "a reissued slot carries a generation no earlier occupant saw" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();
    const slab = SlabAllocator.get();

    const first = try slab.alloc(&vtable);
    const g1 = SlabAllocator.generationOf(first);
    slab.free(first);

    // Same address - the free list hands the slot straight back.
    const second = try slab.alloc(&vtable);
    try testing.expectEqual(first, second);
    const g2 = SlabAllocator.generationOf(second);
    try testing.expect(g2 != g1);
    try testing.expect(g2 != SlabAllocator.dead_generation);

    // Same type, same vtable: the two checks the wrapper cache used to rely on
    // cannot tell these apart; the generation can.
    try testing.expectEqual(first.vtable, second.vtable);
    slab.free(second);
}

test "generations are distinct across slots and across slabs" {
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();
    const slab = SlabAllocator.get();

    // 300 > one slab's 256 slots, so the second slab's init path is covered too.
    var seen = std.AutoHashMap(u64, void).init(testing.allocator);
    defer seen.deinit();
    var instances: [300]*Instance = undefined;
    for (&instances) |*slot| {
        slot.* = try slab.alloc(&vtable);
        const g = SlabAllocator.generationOf(slot.*);
        try testing.expect(g != SlabAllocator.dead_generation);
        try testing.expect(!seen.contains(g));
        try seen.put(g, {});
    }
    for (instances) |inst| slab.free(inst);
}

test "the stamp lives beside the Instance, which stays 24 bytes" {
    try testing.expectEqual(@as(usize, 24), @sizeOf(Instance));
}
