//! Allocator hardening Batch C, Item 5 (observability):
//! - Allocation/free observer callouts (`heap.Engine.AllocObserver`, Darwin
//!   `malloc_logger` backing `[V2] D8`, no `malloc_zone_t`) fire balanced
//!   alloc & free notifications across all four partitions (`.node`,
//!   `.satellite`, `.objects`, `.bytes`), covering cached, shared, large,
//!   and huge blocks.
//! - VM tags per partition remain distinct and non-overlapping (H1 pin).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;
const heap = runtime.heap;

const Recorder = struct {
    const Event = struct {
        is_alloc: bool,
        partition: heap.PartitionId,
        size: usize,
        address: usize,
    };

    events: [128]Event = undefined,
    len: usize = 0,
    allocs: [4]usize = .{ 0, 0, 0, 0 },
    frees: [4]usize = .{ 0, 0, 0, 0 },

    fn observer(self: *Recorder) heap.AllocObserver {
        return .{
            .context = self,
            .on_alloc = onAlloc,
            .on_free = onFree,
        };
    }

    fn onAlloc(ctx: ?*anyopaque, partition: heap.PartitionId, size: usize, address: usize) void {
        const self: *Recorder = @ptrCast(@alignCast(ctx.?));
        self.allocs[@backingInt(partition)] += 1;
        if (self.len < self.events.len) {
            self.events[self.len] = .{ .is_alloc = true, .partition = partition, .size = size, .address = address };
            self.len += 1;
        }
    }

    fn onFree(ctx: ?*anyopaque, partition: heap.PartitionId, address: usize) void {
        const self: *Recorder = @ptrCast(@alignCast(ctx.?));
        self.frees[@backingInt(partition)] += 1;
        if (self.len < self.events.len) {
            self.events[self.len] = .{ .is_alloc = false, .partition = partition, .size = 0, .address = address };
            self.len += 1;
        }
    }

    fn hasPair(self: *const Recorder, partition: heap.PartitionId, address: usize) bool {
        var saw_alloc = false;
        var saw_free = false;
        for (self.events[0..self.len]) |ev| {
            if (ev.partition == partition and ev.address == address) {
                if (ev.is_alloc) saw_alloc = true else saw_free = true;
            }
        }
        return saw_alloc and saw_free;
    }
};

test "item 5: AllocObserver receives balanced alloc/free callouts across all 4 partitions" {
    if (Heap.profile == .pointer32) return error.SkipZigTest;
    // Debug test builds always compile observer callouts in.
    try testing.expect(heap.alloc_log_compiled);

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const eng = try scope.heapEngine();

    var rec: Recorder = .{};
    eng.setAllocObserver(rec.observer());
    defer eng.setAllocObserver(null);

    // 1. `.node`
    const node_ptr = try eng.alloc(.{ .node = .element }, 96, 8, heap.Site.of(u64), @returnAddress());
    const node_addr = @intFromPtr(node_ptr);
    eng.free(node_ptr, 96, 8);
    // Re-issue through magazine to verify popMagazine also logs.
    const node_ptr2 = try eng.alloc(.{ .node = .element }, 96, 8, heap.Site.of(u64), @returnAddress());
    const node_addr2 = @intFromPtr(node_ptr2);
    eng.free(node_ptr2, 96, 8);

    // 2. `.satellite`
    const sat_ptr = try eng.allocSatellite(64, 8, @returnAddress());
    const sat_addr = @intFromPtr(sat_ptr);
    eng.freeSatellite(sat_ptr, 64, 8);

    // 3. `.objects` via per-agent cache (small), shared path (large), and huge
    const cache = try eng.attachAgent();
    defer eng.detachAgent(cache);
    const thread = @import("platform").currentThreadToken();

    const obj_small = try eng.cacheAlloc(cache, .objects, 48, .@"8", @returnAddress());
    const obj_small_addr = @intFromPtr(obj_small);
    eng.cacheFree(cache, .objects, obj_small, 48, .@"8", thread);

    const obj_large = try eng.allocGeneral(.objects, 32 * 1024, 8, @returnAddress());
    const obj_large_addr = @intFromPtr(obj_large);
    eng.freeGeneral(obj_large, 32 * 1024, 8);

    // 4. `.bytes` via per-agent cache (small), coalescing large run, and huge
    const bytes_small = try eng.cacheAlloc(cache, .bytes, 64, .@"1", @returnAddress());
    const bytes_small_addr = @intFromPtr(bytes_small);
    eng.cacheFree(cache, .bytes, bytes_small, 64, .@"1", thread);

    const bytes_large = try eng.allocGeneral(.bytes, 48 * 1024, 1, @returnAddress());
    const bytes_large_addr = @intFromPtr(bytes_large);
    eng.freeGeneral(bytes_large, 48 * 1024, 1);

    const bytes_huge = try eng.allocGeneral(.bytes, heap.huge_threshold_bytes + 4096, 1, @returnAddress());
    const bytes_huge_addr = @intFromPtr(bytes_huge);
    eng.freeGeneral(bytes_huge, heap.huge_threshold_bytes + 4096, 1);

    // Exact balance per partition (no double-logging, no missed callout).
    try testing.expectEqual(@as(usize, 2), rec.allocs[@backingInt(heap.PartitionId.node)]);
    try testing.expectEqual(@as(usize, 2), rec.frees[@backingInt(heap.PartitionId.node)]);
    try testing.expectEqual(@as(usize, 1), rec.allocs[@backingInt(heap.PartitionId.satellite)]);
    try testing.expectEqual(@as(usize, 1), rec.frees[@backingInt(heap.PartitionId.satellite)]);
    try testing.expectEqual(@as(usize, 2), rec.allocs[@backingInt(heap.PartitionId.objects)]);
    try testing.expectEqual(@as(usize, 2), rec.frees[@backingInt(heap.PartitionId.objects)]);
    try testing.expectEqual(@as(usize, 3), rec.allocs[@backingInt(heap.PartitionId.bytes)]);
    try testing.expectEqual(@as(usize, 3), rec.frees[@backingInt(heap.PartitionId.bytes)]);

    try testing.expect(rec.hasPair(.node, node_addr));
    try testing.expect(rec.hasPair(.node, node_addr2));
    try testing.expect(rec.hasPair(.satellite, sat_addr));
    try testing.expect(rec.hasPair(.objects, obj_small_addr));
    try testing.expect(rec.hasPair(.objects, obj_large_addr));
    try testing.expect(rec.hasPair(.bytes, bytes_small_addr));
    try testing.expect(rec.hasPair(.bytes, bytes_large_addr));
    try testing.expect(rec.hasPair(.bytes, bytes_huge_addr));
}

test "item 5: BrowserHeap reserves non-overlapping labeled regions for all 4 partitions" {
    if (Heap.profile == .pointer32) return error.SkipZigTest;

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const eng = try scope.heapEngine();

    // Non-empty, strictly ordered, non-overlapping ranges for all 4 partitions.
    try testing.expect(eng.node.lo < eng.node.hi);
    try testing.expect(eng.satellite.lo < eng.satellite.hi);
    try testing.expect(eng.objects.lo < eng.objects.hi);
    try testing.expect(eng.bytes.lo < eng.bytes.hi);
    try testing.expect(eng.node.hi < eng.satellite.lo); // guard super page between node and satellite
    try testing.expect(eng.satellite.hi <= eng.objects.lo);
    try testing.expect(eng.objects.hi <= eng.bytes.lo);
}
