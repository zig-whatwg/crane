//! Allocator hardening, batch B2, the span engine's `.satellite` partition
//! (tmp/plans/allocator-hardening-design.md §§1.2, 3.1, 3.3–3.7, 7 Batch B
//! item 3): `Engine.allocSatellite` / `freeSatellite` / `freeSatelliteOf` /
//! `resizesSatelliteInPlace` and `heap.satellite.allocatorOf`.
//!
//! Covers:
//! - Cage placement & `BrowserHeap.Link` interoperability with `.node`;
//! - Strict partition separation (`.satellite` vs `.node`/`.objects`/`.bytes`);
//! - Validated frees (double, interior, wrong size, other heap);
//! - Full-block zero-on-free + write-after-free detection (production & poison);
//! - Task-scoped quarantine & purge;
//! - Window-thread-only owner enforcement (`.wrong_thread`);
//! - 200 ms idle decommit + inactive bitmap page decommit;
//! - Large runs, huge satellite blocks, in-place same-class resize, stats & leakReport.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;
const heap = runtime.heap;

fn satelliteEngine(scope: *BrowserScope) !*heap.Engine {
    const engine = try scope.heapEngine();
    if (Heap.profile == .pointer32) return error.SkipZigTest;
    return engine;
}

test "satellite blocks live in the cage and encode/decode via Link against node blocks" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);

    const node_ptr = try engine.alloc(.{ .node = .element }, 112, 8, heap.Site.of(u64), @returnAddress());
    defer engine.free(node_ptr, 112, 8);
    const sat_ptr = try engine.allocSatellite(64, 8, @returnAddress());
    defer engine.freeSatellite(sat_ptr, 64, 8);

    try testing.expectEqual(heap.PartitionId.node, engine.partitionOf(node_ptr).?);
    try testing.expectEqual(heap.PartitionId.satellite, engine.partitionOf(sat_ptr).?);
    // Issued zeroed.
    try testing.expect(std.mem.allEqual(u8, sat_ptr[0..64], 0));

    // Both sit inside the node cage, so 32-bit Links work directly between them (N10 ready).
    const sat_offset = @intFromPtr(sat_ptr) - engine.heap.window_base;
    try testing.expect(sat_offset >= Heap.layout.cage.offset and sat_offset < Heap.layout.cage.end());
    const link = try Heap.Link(u8).encode(@ptrCast(sat_ptr), node_ptr);
    try testing.expectEqual(@as(?*u8, @ptrCast(sat_ptr)), try link.decode(node_ptr));
}

test "satellite frees are validated: double, interior, wrong size, cross-partition and other heap" {
    var a = BrowserScope.init(testing.allocator);
    defer a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();
    const ea = try satelliteEngine(&a);
    const eb = try satelliteEngine(&b);
    ea.checks = .report;
    eb.checks = .report;

    const p = try ea.allocSatellite(48, 8, @returnAddress());
    // Interior pointer.
    ea.freeSatellite(p + 8, 40, 8);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), ea.takeViolation());
    // Wrong size class.
    ea.freeSatellite(p, 272, 8);
    try testing.expectEqual(@as(?heap.Violation, .wrong_size), ea.takeViolation());
    // Wrong entry point (State free or general free on a satellite block).
    ea.free(p, 48, 8);
    try testing.expectEqual(@as(?heap.Violation, .invalid_free), ea.takeViolation());
    if (ea.heap.general_pools) {
        ea.freeGeneral(p, 48, 8);
        try testing.expectEqual(@as(?heap.Violation, .invalid_free), ea.takeViolation());
    }
    // Other Browser's heap.
    eb.freeSatellite(p, 48, 8);
    try testing.expectEqual(@as(?heap.Violation, .other_heap), eb.takeViolation());
    // Valid free, then double free.
    ea.freeSatellite(p, 48, 8);
    try testing.expectEqual(@as(?heap.Violation, null), ea.takeViolation());
    ea.freeSatellite(p, 48, 8);
    try testing.expectEqual(@as(?heap.Violation, .double_free), ea.takeViolation());
}

test "production satellite config zeroes whole block on free and catches write-after-free at reissue" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);
    engine.configureForTest(heap.Config.production);
    engine.checks = .report;

    // 272 B (ElementStyle exact class) — whole block zeroed on free.
    const block = try engine.allocSatellite(272, 8, @returnAddress());
    @memset(block[0..272], 0x5a);
    engine.freeSatellite(block, 272, 8);
    try testing.expect(std.mem.allEqual(u8, block[0..272], 0));

    // Simulate a write-after-free near the tail of the block; reissue catches it.
    block[260] = 0x1;
    const reissued = try engine.allocSatellite(272, 8, @returnAddress());
    defer engine.freeSatellite(reissued, 272, 8);
    try testing.expectEqual(@intFromPtr(block), @intFromPtr(reissued));
    try testing.expectEqual(@as(?heap.Violation, .write_after_free), engine.takeViolation());
    // Reissued block is zeroed cleanly after reporting.
    try testing.expect(std.mem.allEqual(u8, reissued[0..272], 0));
}

test "satellite blocks freed during a window task are quarantined until endTask" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);

    engine.beginTask();
    const a = try engine.allocSatellite(64, 8, @returnAddress());
    engine.freeSatellite(a, 64, 8);
    try testing.expect(engine.isQuarantined(a));
    try testing.expectEqual(@as(usize, 1), engine.stats().satellite.quarantined_blocks);

    // Next allocation in the same task must not reuse the quarantined slot.
    const b = try engine.allocSatellite(64, 8, @returnAddress());
    try testing.expect(@intFromPtr(a) != @intFromPtr(b));

    // Double-freeing a quarantined satellite block is caught.
    engine.checks = .report;
    engine.freeSatellite(a, 64, 8);
    try testing.expectEqual(@as(?heap.Violation, .double_free), engine.takeViolation());
    engine.checks = .panic;

    engine.freeSatellite(b, 64, 8);
    engine.endTask();
    try testing.expect(!engine.isQuarantined(a));
    try testing.expectEqual(@as(usize, 0), engine.stats().satellite.quarantined_blocks);
}

test "satellite allocation or free off the window thread reports wrong_thread" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);
    engine.checks = .report;

    // Establish window thread owner.
    const sat = try engine.allocSatellite(32, 8, @returnAddress());
    defer engine.freeSatellite(sat, 32, 8);

    const Worker = struct {
        engine: *heap.Engine,
        sat: [*]u8,
        alloc_failed: bool = false,
        alloc_violation: ?heap.Violation = null,
        free_violation: ?heap.Violation = null,

        fn run(self: *@This()) void {
            if (self.engine.allocSatellite(32, 8, @returnAddress())) |p| {
                self.engine.freeSatellite(p, 32, 8);
            } else |_| {
                self.alloc_failed = true;
            }
            self.alloc_violation = self.engine.takeViolation();
            self.engine.freeSatellite(self.sat, 32, 8);
            self.free_violation = self.engine.takeViolation();
        }
    };
    var worker: Worker = .{ .engine = engine, .sat = sat };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&worker});
    thread.join();
    try testing.expect(worker.alloc_failed);
    try testing.expectEqual(@as(?heap.Violation, .wrong_thread), worker.alloc_violation);
    try testing.expectEqual(@as(?heap.Violation, .wrong_thread), worker.free_violation);
}

test "idle decommit reclaims empty satellite spans and inactive bitmap pages after 200 ms" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);

    engine.setNow(1_000);
    var blocks: [256][*]u8 = undefined;
    for (&blocks) |*slot| slot.* = try engine.allocSatellite(272, 8, @returnAddress());
    for (blocks) |b| engine.freeSatellite(b, 272, 8);

    const before = engine.stats().satellite;
    try testing.expectEqual(@as(usize, 0), before.live_blocks);

    // At 1,250 ms (> 200 ms idle), every empty satellite span and its bitmap page decommit.
    const r = engine.decommitAged(1_250, heap.decommit_age_ms, 1024);
    try testing.expect(r.decommitted > 0);
    const after = engine.stats().satellite;
    try testing.expectEqual(@as(usize, 0), after.spans_active);
    try testing.expect(after.spans_decommitted > 0);
    try testing.expect(after.bitmap_pages_decommitted > 0);

    // Reusing after decommit + bitmap decommit works cleanly.
    const fresh = try engine.allocSatellite(272, 8, @returnAddress());
    defer engine.freeSatellite(fresh, 272, 8);
    try testing.expect(std.mem.allEqual(u8, fresh[0..272], 0));
}

test "satellite allocator supports large runs, huge blocks, freeSatelliteOf, in-place resize, stats and leakReport" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const engine = try satelliteEngine(&scope);
    const sat_alloc = scope.satelliteAllocator();

    // Large run (32 KiB).
    const large = try sat_alloc.alloc(u64, 4096);
    try testing.expectEqual(heap.PartitionId.satellite, engine.partitionOf(large.ptr).?);
    sat_alloc.free(large);

    // Huge satellite block (> 2 MiB) & region reuse.
    const huge_len = 3 * 1024 * 1024 + 64;
    const huge = try engine.allocSatellite(huge_len, 8, @returnAddress());
    try testing.expectEqual(heap.PartitionId.satellite, engine.partitionOf(huge).?);
    huge[0] = 7;
    huge[huge_len - 1] = 9;
    engine.freeSatellite(huge, huge_len, 8);
    const huge_again = try engine.allocSatellite(huge_len, 8, @returnAddress());
    try testing.expectEqual(@intFromPtr(huge), @intFromPtr(huge_again));
    try testing.expectEqual(@as(u8, 0), huge_again[0]);
    try testing.expectEqual(@as(u8, 0), huge_again[huge_len - 1]);
    engine.freeSatellite(huge_again, huge_len, 8);

    // freeSatelliteOf via heapOf contract.
    const via_heap_of = try engine.allocSatellite(128, 8, @returnAddress());
    heap.Engine.freeSatelliteOf(via_heap_of, 128, 8);

    // In-place resize within same 16-B class succeeds; crossing a class returns false.
    try testing.expect(engine.resizesSatelliteInPlace(8, 16, 8));
    try testing.expect(!engine.resizesSatelliteInPlace(16, 32, 8));

    // Stats & leakReport count live satellite blocks.
    const live = try sat_alloc.create(u64);
    try testing.expectEqual(@as(usize, 1), engine.stats().satellite.live_blocks);
    const Count = struct {
        fn line(seen: *usize, l: heap.LeakLine) void {
            if (l.partition == .satellite) seen.* += l.count;
        }
    };
    var seen: usize = 0;
    try testing.expectEqual(@as(usize, 1), engine.leakReport(&seen, Count.line));
    try testing.expectEqual(@as(usize, 1), seen);
    sat_alloc.destroy(live);
    try testing.expectEqual(@as(usize, 0), engine.stats().satellite.live_blocks);
}
