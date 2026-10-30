//! Lane rendering3: the effect stack's target index (which effects apply to
//! which element, rebuilt each time the values revision moves - every frame
//! while an animation runs) must not allocate in the steady state.
//!
//! The WPT runner's DebugAllocator never reuses a freed slot and unmaps a
//! bucket the moment its last live slot is freed. A list freed and allocated
//! again every frame moved which buckets of its size class stayed live, and
//! every getComputedStyle read of an UNANIMATED element beside one running
//! animation then mapped and unmapped pages for its own short-lived
//! allocations of that class: crane/r3-cost-one-spinner.html read 31% slower
//! (about one extra page fault per read). A rebuild that finds the same
//! targets keeps their storage.
const std = @import("std");
const dom = @import("dom");
const TargetIndex = dom.animations.effect_stack.TargetIndex;
const Link = dom.animations.model.Link;

const testing = std.testing;

fn noOrder(_: void, _: Link, _: Link) bool {
    return false;
}

const target_a: TargetIndex.Key = .{ .address = 0x10000, .generation = 1 };
const target_b: TargetIndex.Key = .{ .address = 0x20000, .generation = 1 };
const effect_a: Link = .{ .instance = @ptrFromInt(0x30000), .generation = 1 };
const effect_b: Link = .{ .instance = @ptrFromInt(0x40000), .generation = 1 };

test "r3: rebuilding an unchanged target index allocates and frees nothing" {
    var failing: testing.FailingAllocator = .init(testing.allocator, .{});
    const allocator = failing.allocator();
    var index: TargetIndex = .{};
    defer index.deinit(allocator);

    // The first frame of a running animation builds the index.
    index.begin();
    try index.add(allocator, target_a, effect_a);
    index.finish(allocator, {}, noOrder);
    try testing.expectEqual(@as(usize, 1), index.effectsOf(target_a).?.len);

    // Every later frame: the same effect on the same target.
    failing.fail_index = failing.alloc_index;
    const frees = failing.deallocations;
    for (0..3) |_| {
        index.begin();
        try index.add(allocator, target_a, effect_a);
        index.finish(allocator, {}, noOrder);
    }
    try testing.expectEqual(frees, failing.deallocations);
    try testing.expectEqual(@as(usize, 1), index.effectsOf(target_a).?.len);
    try testing.expect(index.effectsOf(target_b) == null);
}

test "r3: a target no effect applies to any more leaves the target index" {
    var index: TargetIndex = .{};
    defer index.deinit(testing.allocator);
    index.begin();
    try index.add(testing.allocator, target_a, effect_a);
    try index.add(testing.allocator, target_b, effect_b);
    index.finish(testing.allocator, {}, noOrder);

    // target_b's animation ended: its entry and its list go.
    index.begin();
    try index.add(testing.allocator, target_a, effect_a);
    index.finish(testing.allocator, {}, noOrder);
    try testing.expectEqual(@as(usize, 1), index.map.count());
    try testing.expect(index.effectsOf(target_b) == null);
    try testing.expectEqual(effect_a.instance, index.effectsOf(target_a).?[0].instance);

    // Nothing applies: the index is empty.
    index.begin();
    index.finish(testing.allocator, {}, noOrder);
    try testing.expectEqual(@as(usize, 0), index.map.count());
    try testing.expect(index.effectsOf(target_a) == null);
}

test "r3: targets that come and go leave the target index's probes short" {
    // A page that animates a new element every frame: each one leaves the
    // index a frame later, as a tombstone. Unguarded, those take every free
    // slot of the table and each miss walks all of it; the guard rehashes
    // before an insert while they could take half of the unused slots
    // (src/infra/tombstones.zig).
    const tombstones = @import("infra").tombstones;
    var index: TargetIndex = .{};
    defer index.deinit(testing.allocator);
    for (0..2000) |i| {
        index.begin();
        const key: TargetIndex.Key = .{ .address = 0x10000 + i * 0x100, .generation = 1 };
        try index.add(testing.allocator, key, effect_a);
        index.finish(testing.allocator, {}, noOrder);
        try testing.expectEqual(@as(usize, 1), index.map.count());
        const counts = tombstones.slotCounts(&index.map);
        try testing.expect(counts.free * 4 >= counts.capacity - counts.live);
    }
}

fn buildTwice(allocator: std.mem.Allocator) !void {
    var index: TargetIndex = .{};
    defer index.deinit(allocator);
    for (0..2) |_| {
        index.begin();
        try index.add(allocator, target_a, effect_a);
        try index.add(allocator, target_b, effect_b);
        try index.add(allocator, target_a, effect_b);
        index.finish(allocator, {}, noOrder);
    }
    try testing.expectEqual(@as(usize, 2), index.effectsOf(target_a).?.len);
}

test "r3: the target index under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, buildTwice, .{});
}
