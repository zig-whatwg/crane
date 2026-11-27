//! Allocator hardening follow-up tests (lane hard-fix1):
//! - Item 3 (§4.4): Never commit the `0xDDDDDDDD` poison super page in the cage.
//! - Item 4 (§3.1, §4.1, §7 B.2): Comptime-typed `heap.create`/`destroy`/`alloc`/`free`
//!   and `allocAligned`/`freeAligned` routing.
//! - Item 6 (§5.1, §7 A.1): Per-class stats (`classStats`) and exact
//!   `free_bytes_in_active_spans` accounting.
//! - Item 7 (§4.4): N11/H3 preparation — `node_stamp_skip_bytes` fill/verify and
//!   `nodeSpans` / `forEachLiveNode` iteration.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;
const heap = runtime.heap;

// ============================================================================
// Item 3 (§4.4): Never commit the 0xDDDDDDDD poison super page in the cage
// ============================================================================

test "item 3: openSpan and allocHuge never commit or allocate inside the 0xDDDDDDDD poison super page" {
    if (Heap.profile != .full) return error.SkipZigTest;

    const poison_link_offset: usize = @intCast(Heap.poison_link_offset);
    const super_page: usize = @intCast(Heap.super_page_bytes);
    const poison_lo: usize = @intCast(Heap.poison_super_page_offset);
    const poison_hi: usize = poison_lo + super_page;
    try testing.expectEqual(@as(usize, 0xDDC0_0000), poison_lo);
    try testing.expectEqual(@as(usize, 0xDDE0_0000), poison_hi);
    try testing.expect(poison_link_offset >= poison_lo and poison_link_offset < poison_hi);
    try testing.expect(Heap.overlapsPoisonSuperPage(poison_link_offset, 1));
    try testing.expect(Heap.overlapsPoisonSuperPage(poison_lo, super_page));
    try testing.expect(Heap.overlapsPoisonSuperPage(poison_lo - heap.span_bytes, heap.span_bytes * 2));
    try testing.expect(!Heap.overlapsPoisonSuperPage(poison_lo - heap.span_bytes, heap.span_bytes));
    try testing.expect(!Heap.overlapsPoisonSuperPage(poison_hi, super_page));

    // 1. Small/class span opened right at the poison super page skips it.
    {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        const eng = try scope.heapEngine();
        const page = eng.page;
        try testing.expect(poison_lo >= eng.satellite.lo and poison_hi <= eng.satellite.hi);

        // Position satellite frontier right at the start of the poison super page.
        eng.satellite.frontier = poison_lo;
        eng.satellite.data_hi = poison_lo;
        eng.satellite.table_hi = std.mem.alignBackward(
            usize,
            @as(usize, @intCast(Heap.layout.span_table.offset)) + (poison_lo / heap.span_bytes) * @as(usize, @intCast(Heap.span_entry_bytes)),
            page,
        );
        eng.satellite.map_hi = std.mem.alignBackward(
            usize,
            @as(usize, @intCast(Heap.layout.bitmaps.offset)) + (poison_lo / heap.span_bytes) * @as(usize, @intCast(Heap.slot_map_bytes)),
            page,
        );

        const ptr = try eng.allocSatellite(64, 8, @returnAddress());
        defer eng.freeSatellite(ptr, 64, 8);
        const offset = @intFromPtr(ptr) - eng.heap.window_base;
        try testing.expect(offset >= poison_hi);
    }

    // 2. Huge satellite allocation starting right before the poison super page skips it.
    {
        var scope = BrowserScope.init(testing.allocator);
        defer scope.deinit();
        const eng = try scope.heapEngine();
        const page = eng.page;
        const before_poison = poison_lo - super_page;

        eng.satellite.frontier = before_poison;
        eng.satellite.data_hi = before_poison;
        eng.satellite.table_hi = std.mem.alignBackward(
            usize,
            @as(usize, @intCast(Heap.layout.span_table.offset)) + (before_poison / heap.span_bytes) * @as(usize, @intCast(Heap.span_entry_bytes)),
            page,
        );
        eng.satellite.map_hi = std.mem.alignBackward(
            usize,
            @as(usize, @intCast(Heap.layout.bitmaps.offset)) + (before_poison / heap.span_bytes) * @as(usize, @intCast(Heap.slot_map_bytes)),
            page,
        );

        // A 3 MiB huge allocation starting at `before_poison` would span across
        // `[poison_lo, poison_hi)` unless `allocHuge` skips past `poison_hi`.
        const huge_len = 3 * 1024 * 1024;
        const ptr = try eng.allocSatellite(huge_len, 8, @returnAddress());
        defer eng.freeSatellite(ptr, huge_len, 8);
        const offset = @intFromPtr(ptr) - eng.heap.window_base;
        try testing.expect(offset >= poison_hi);
    }
}

// ============================================================================
// Item 4 (§3.1, §4.1, §7 B.2): Comptime-typed heap.create / heap.alloc routing
// ============================================================================

test "item 4: containsPointer and partitionForType classify scalar and pointer-bearing types at comptime" {
    const ScalarOnly = struct { a: u64, b: u32, c: [16]u8 };
    const ScalarUnion = union(enum) { int: u64, bytes: [8]u8 };
    const WithPtr = struct { count: u32, next: ?*ScalarOnly };
    const WithSlice = struct { text: []const u8 };
    const WithNestedPtr = struct { items: [2]WithPtr };
    const PtrUnion = union(enum) { none: void, ptr: *u8 };
    const ComptimePtrOnly = struct { comptime tag: []const u8 = "x", val: u32 };

    comptime {
        std.debug.assert(!heap.containsPointer(u8));
        std.debug.assert(!heap.containsPointer(u64));
        std.debug.assert(!heap.containsPointer(ScalarOnly));
        std.debug.assert(!heap.containsPointer(ScalarUnion));
        std.debug.assert(!heap.containsPointer(ComptimePtrOnly));
        std.debug.assert(heap.partitionForType(u8) == .bytes);
        std.debug.assert(heap.partitionForType(u64) == .bytes);
        std.debug.assert(heap.partitionForType(ScalarOnly) == .bytes);
        std.debug.assert(heap.partitionForType(ScalarUnion) == .bytes);

        std.debug.assert(heap.containsPointer(*u8));
        std.debug.assert(heap.containsPointer([]const u8));
        std.debug.assert(heap.containsPointer(?*anyopaque));
        std.debug.assert(heap.containsPointer(WithPtr));
        std.debug.assert(heap.containsPointer(WithSlice));
        std.debug.assert(heap.containsPointer(WithNestedPtr));
        std.debug.assert(heap.containsPointer(PtrUnion));
        std.debug.assert(heap.partitionForType(WithPtr) == .objects);
        std.debug.assert(heap.partitionForType(WithSlice) == .objects);
        std.debug.assert(heap.partitionForType(WithNestedPtr) == .objects);
        std.debug.assert(heap.partitionForType(PtrUnion) == .objects);
    }
    try testing.expectEqual(heap.PartitionId.bytes, heap.partitionForType(ScalarOnly));
    try testing.expectEqual(heap.PartitionId.objects, heap.partitionForType(WithPtr));
}

test "item 4: heap.create/destroy/alloc/free route pointer types to .objects and bytes/scalars to .bytes" {
    if (Heap.profile != .full) return error.SkipZigTest;

    const ScalarRecord = struct { a: u64, b: u64 };
    const PtrRecord = struct { a: u64, ptr: ?*u8 };

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const eng = try scope.heapEngine();
    const cache = try eng.attachAgent();
    defer eng.detachAgent(cache);
    const agent_alloc = cache.allocator();
    const shared_alloc = heap.general.allocatorOf(eng);

    // 1. Via *Engine directly
    {
        const p_obj = try heap.create(eng, PtrRecord);
        defer heap.destroy(eng, p_obj);
        try testing.expectEqual(heap.PartitionId.objects, eng.partitionOf(p_obj).?);

        const p_scalar = try heap.create(eng, ScalarRecord);
        defer heap.destroy(eng, p_scalar);
        // Even though @alignOf(ScalarRecord) == 8, comptime typed routing puts pointer-free scalars in .bytes!
        try testing.expectEqual(heap.PartitionId.bytes, eng.partitionOf(p_scalar).?);

        const s_bytes = try heap.alloc(eng, u8, 64);
        defer heap.free(eng, s_bytes);
        try testing.expectEqual(heap.PartitionId.bytes, eng.partitionOf(s_bytes.ptr).?);

        const s_aligned = try heap.allocAligned(eng, u8, .@"16", 64);
        defer heap.freeAligned(eng, s_aligned, .@"16");
        try testing.expectEqual(heap.PartitionId.bytes, eng.partitionOf(s_aligned.ptr).?);
        try testing.expectEqual(@as(usize, 0), @intFromPtr(s_aligned.ptr) % 16);
    }

    // 2. Via *AgentCache and std.mem.Allocator (both agent and shared)
    {
        const p_obj = try runtime.heapCreate(agent_alloc, PtrRecord);
        defer runtime.heapDestroy(agent_alloc, p_obj);
        try testing.expectEqual(heap.PartitionId.objects, eng.partitionOf(p_obj).?);

        const s_obj = try runtime.heapAlloc(cache, PtrRecord, 4);
        defer runtime.heapFree(cache, s_obj);
        try testing.expectEqual(heap.PartitionId.objects, eng.partitionOf(s_obj.ptr).?);

        const s_bytes = try runtime.heapAllocAligned(agent_alloc, u8, .@"16", 128);
        defer runtime.heapFreeAligned(agent_alloc, s_bytes, .@"16");
        try testing.expectEqual(heap.PartitionId.bytes, eng.partitionOf(s_bytes.ptr).?);
        try testing.expectEqual(@as(usize, 0), @intFromPtr(s_bytes.ptr) % 16);

        const s_shared = try heap.alloc(shared_alloc, u64, 8);
        defer heap.free(shared_alloc, s_shared);
        try testing.expectEqual(heap.PartitionId.bytes, eng.partitionOf(s_shared.ptr).?);
    }

    // 3. Fallback host std.mem.Allocator (testing.allocator) + empty/ZST edge cases
    {
        const p = try heap.create(testing.allocator, PtrRecord);
        defer heap.destroy(testing.allocator, p);
        p.* = .{ .a = 7, .ptr = null };

        const buf = try heap.allocAligned(testing.allocator, u8, .@"16", 32);
        defer heap.freeAligned(testing.allocator, buf, .@"16");
        try testing.expectEqual(@as(usize, 0), @intFromPtr(buf.ptr) % 16);

        const empty = try heap.alloc(agent_alloc, u8, 0);
        heap.free(agent_alloc, empty);
        const z = try heap.create(agent_alloc, void);
        heap.destroy(agent_alloc, z);
    }
}

// ============================================================================
// Item 6 (§5.1, §7 A.1): Per-class stats and active-span slack accounting
// ============================================================================

test "item 6: free_bytes_in_active_spans and classStats track exact active-span slack" {
    if (Heap.profile != .full) return error.SkipZigTest;

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const eng = try scope.heapEngine();

    // Use a 4096 B general objects block (> cache_max_bytes = 2048, so no AgentCache
    // or magazine pinning): exact slot count per span is `heap.span_bytes / 4096`.
    const block_size: usize = 4096;
    const slots_per_span: usize = heap.span_bytes / block_size;
    try testing.expect(slots_per_span >= 4);

    // Initially: 0 active-span slack.
    try testing.expectEqual(@as(usize, 0), eng.stats().general_objects.free_bytes_in_active_spans);

    // Allocate 1 block: (slots_per_span - 1) slots remain free in the active span.
    const p0 = try eng.allocGeneral(.objects, block_size, 8, @returnAddress());
    try testing.expectEqual((slots_per_span - 1) * block_size, eng.stats().general_objects.free_bytes_in_active_spans);

    // Fill the entire span: 0 free bytes in active spans.
    var rest = try testing.allocator.alloc([*]u8, slots_per_span - 1);
    defer testing.allocator.free(rest);
    for (0..slots_per_span - 1) |i| {
        rest[i] = try eng.allocGeneral(.objects, block_size, 8, @returnAddress());
    }
    try testing.expectEqual(@as(usize, 0), eng.stats().general_objects.free_bytes_in_active_spans);

    // Free 1 block: exactly 1 slot (4096 B) of slack in the active span.
    eng.freeGeneral(p0, block_size, 8);
    try testing.expectEqual(block_size, eng.stats().general_objects.free_bytes_in_active_spans);

    // Verify classStats matches PartitionStats exactly.
    const Collector = struct {
        seen: usize = 0,
        slack_general: usize = 0,
        slack_state: usize = 0,
        va_total: usize = 0,
        fn visit(self: *@This(), cs: heap.ClassStats) void {
            self.seen += 1;
            self.va_total += cs.va_assigned;
            if (cs.general) self.slack_general += cs.free_bytes_in_active_spans else self.slack_state += cs.free_bytes_in_active_spans;
        }
    };
    var col: Collector = .{};
    eng.classStats(.objects, &col, Collector.visit);
    try testing.expect(col.seen >= 1);
    try testing.expectEqual(block_size, col.slack_general);
    try testing.expectEqual(eng.stats().general_objects.free_bytes_in_active_spans, col.slack_general);
    try testing.expectEqual(eng.stats().objects.free_bytes_in_active_spans, col.slack_state);
    try testing.expect(col.va_total >= heap.span_bytes);

    // Free the remaining blocks: span becomes empty-cached -> 0 active-span slack.
    for (rest) |p| eng.freeGeneral(p, block_size, 8);
    try testing.expectEqual(@as(usize, 0), eng.stats().general_objects.free_bytes_in_active_spans);

    // Node quarantine accounting in classStats during a task.
    eng.beginTask();
    const n1 = try eng.alloc(.{ .node = .element }, 112, 8, heap.Site.of(u64), @returnAddress());
    const n2 = try eng.alloc(.{ .node = .element }, 112, 8, heap.Site.of(u64), @returnAddress());
    eng.free(n1, 112, 8);
    var q_seen: usize = 0;
    var node_slack: usize = 0;
    const NodeCol = struct {
        q: *usize,
        slack: *usize,
        fn visit(self: @This(), cs: heap.ClassStats) void {
            self.q.* += cs.quarantined_blocks;
            self.slack.* += cs.free_bytes_in_active_spans;
        }
    };
    eng.classStats(.node, NodeCol{ .q = &q_seen, .slack = &node_slack }, NodeCol.visit);
    try testing.expectEqual(@as(usize, 1), q_seen);
    try testing.expectEqual(eng.stats().node.free_bytes_in_active_spans, node_slack);
    try testing.expectEqual(((heap.span_bytes / 112) - 2) * 112, node_slack);
    eng.free(n2, 112, 8);
    eng.endTask();
}
