//! The wrapper cache's pool of records, alone (lane wrap1 b3's pool; moved here by lane wrap2).
//!
//! The cache issues its 32-byte records from 1 KB chunks of its own (wrapper_cache.zig `Chunk`): a record finds
//! its cache by masking its address, a chunk nothing uses goes back to the allocator, and one chunk with room
//! stays so that a wrapper made and dropped at a chunk's edge does not allocate each time. These two tests were
//! written inside wrapper_cache.zig, where no test is ever collected (build.zig, "V8 engine tests": only
//! tests/**/*_test.zig is), so they had never run. They need no engine: the records are never attached to a
//! wrapper and never enter the cache's map. What the pool does under real collections is
//! tests/v8/wrap1_platform_anchor_test.zig ("the cache's pool of records gives its memory back ...").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const test_process = @import("test_process.zig");
const WrapperCache = v8.WrapperCache;

/// A cache no realm owns, on a context that is never read.
const Fixture = struct {
    context_word: u32 = 42,

    fn context(self: *Fixture) *v8.Context {
        return @ptrCast(&self.context_word);
    }
};

/// Stand-ins for instances: a slab slot's worth of zeroed memory each. Only the slot's stamp word is read
/// (runtime.SlabAllocator.generationOf), and nothing of an instance is called.
const Slot = struct {
    words: [(runtime.SlabAllocator.slot_bytes + 7) / 8]u64,
};

fn instanceOf(slot: *Slot) *runtime.Instance {
    return @ptrCast(slot);
}

test "a wrapper cache with no record begins and ends" {
    test_process.start();
    var fixture: Fixture = .{};
    var cache = try WrapperCache.init(testing.allocator, fixture.context());
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 0), cache.size());
    try testing.expectEqual(@as(usize, 0), cache.chunk_count);
}

test "the pool issues 32-byte records that find their cache, takes them back, and gives its spare chunks to the allocator" {
    test_process.start();
    var fixture: Fixture = .{};
    var cache = try WrapperCache.init(testing.allocator, fixture.context());
    defer cache.deinit();

    try testing.expectEqual(@as(usize, 32), @sizeOf(v8.wrapper_cache_mod.Cell));
    const per_chunk = WrapperCache.records_per_chunk;
    try testing.expect(per_chunk >= 16);

    // Two chunks' worth and one more: three chunks.
    const count = 2 * per_chunk + 1;
    var slots: [count]Slot = undefined;
    for (&slots) |*slot| slot.* = .{ .words = @splat(0) };
    var cells: [count]*v8.wrapper_cache_mod.Cell = undefined;
    for (&slots, &cells) |*slot, *cell| {
        cell.* = try cache.allocRecordForTest(instanceOf(slot), 7);
        try testing.expect(cache.ownsRecordForTest(cell.*));
        try testing.expect(cell.*.bits.in_use and cell.*.bits.boxed);
        try testing.expectEqual(@as(u32, 7), cell.*.fresh);
        try testing.expect(cell.*.instance == instanceOf(slot));
    }
    try testing.expectEqual(@as(usize, 3), cache.chunk_count);
    // Every record is its own.
    for (cells, 0..) |cell, i| {
        for (cells[i + 1 ..]) |other| try testing.expect(cell != other);
    }

    for (cells) |cell| cache.freeRecordForTest(cell);
    // The chunks nothing uses went back to the allocator; one stays, and records are issued from it.
    try testing.expectEqual(@as(usize, 1), cache.chunk_count);
    try testing.expect(cache.poolIsOneOpenChunkForTest());

    // A freed record is issued again before the pool grows.
    const again = try cache.allocRecordForTest(instanceOf(&slots[0]), 0);
    try testing.expectEqual(cells[cells.len - 1], again);
    try testing.expectEqual(@as(u32, 0), again.fresh);
    try testing.expectEqual(@as(usize, 1), cache.chunk_count);
    cache.freeRecordForTest(again);

    // A walk that frees records gives no chunk back until it ends.
    for (&slots, &cells) |*slot, *cell| cell.* = try cache.allocRecordForTest(instanceOf(slot), 0);
    try testing.expectEqual(@as(usize, 3), cache.chunk_count);
    cache.beginPoolWalkForTest();
    for (cells) |cell| cache.freeRecordForTest(cell);
    try testing.expectEqual(@as(usize, 3), cache.chunk_count);
    cache.endPoolWalkForTest();
    try testing.expectEqual(@as(usize, 1), cache.chunk_count);
    try testing.expect(cache.poolIsOneOpenChunkForTest());
}
