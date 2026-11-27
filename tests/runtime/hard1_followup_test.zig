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
