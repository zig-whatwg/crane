//! Side tables keyed by an object's address stay fast when page after page of
//! entries comes and goes (src/webidl/utils/tombstones.zig).
//!
//! The churn is a runner's: a page's worth of objects at addresses never used
//! before is registered and then released, forty times over, while a few
//! objects stay registered throughout. Each page is checked at its first
//! insert - the moment the previous page's removals are behind the map and the
//! next page's inserts start probing.

const std = @import("std");
const webidl = @import("webidl");
const tombstones = webidl.utils.tombstones;

const pages = 40;
const per_page = 4096;
const resident = 64;
/// Keys are addresses: 16-byte steps, as a slab hands them out.
const stride = 16;

/// The slots a probe for `key`, not in `map`, visits before it can stop -
/// from the key's home slot to the first FREE one, as std's
/// getOrPutAssumeCapacityAdapted walks for every new key.
fn absentProbe(map: *const std.AutoHashMap(usize, u32), key: usize) usize {
    const capacity = map.capacity();
    if (capacity == 0) return 0;
    const metadata: [*]const u8 = @ptrCast(map.unmanaged.metadata.?);
    const context: std.hash_map.AutoContext(usize) = .{};
    var index: usize = @intCast(context.hash(key) & (capacity - 1));
    var visited: usize = 0;
    while (metadata[index] != 0 and visited < capacity) : (visited += 1) {
        index = (index + 1) & (capacity - 1);
    }
    return visited;
}

/// Mean `absentProbe` over 256 keys no page will ever use.
fn meanAbsentProbe(map: *const std.AutoHashMap(usize, u32)) usize {
    var total: usize = 0;
    for (0..256) |i| total += absentProbe(map, 0x7000_0000_0000 + i * stride);
    return total / 256;
}

/// Run the churn over `map`, with `guard` or without; returns the worst mean
/// absent probe seen at a page's first insert.
fn churn(map: *std.AutoHashMap(usize, u32), guard: ?*tombstones.TombstoneGuard) !usize {
    var next: usize = 0x1000;
    for (0..resident) |_| {
        if (guard) |g| g.beforeInsert(map);
        try map.put(next, 1);
        next += stride;
    }
    var worst: usize = 0;
    for (0..pages) |page| {
        const first = next;
        for (0..per_page) |i| {
            if (guard) |g| g.beforeInsert(map);
            try map.put(next, 2);
            next += stride;
            if (i == 0 and page > 0) worst = @max(worst, meanAbsentProbe(map));
        }
        var key = first;
        while (key < next) : (key += stride) {
            if (map.remove(key)) {
                if (guard) |g| g.noteRemoval(map);
            }
        }
    }
    return worst;
}

test "std.HashMap under a runner's churn: without a rehash, a probe for a new key walks ever further" {
    // The reason the guard exists, measured on std itself: every removal
    // leaves a tombstone, nothing clears them while inserts and removes
    // balance, and a probe for an absent key stops only at a FREE slot.
    var map = std.AutoHashMap(usize, u32).init(std.testing.allocator);
    defer map.deinit();
    const worst = try churn(&map, null);
    const counts = tombstones.slotCounts(&map);
    try std.testing.expect(!counts.halfOfUnusedFree());
    try std.testing.expect(worst > 64);
}

test "TombstoneGuard: at every page's first insert, half the unused slots are free and probes stay short" {
    var map = std.AutoHashMap(usize, u32).init(std.testing.allocator);
    defer map.deinit();
    var guard: tombstones.TombstoneGuard = .{};
    const worst = try churn(&map, &guard);
    // Probing a table at most half taken, as a map that never removed
    // anything would be: a few slots.
    if (worst > 8) {
        std.debug.print("worst mean probe for an absent key: {d} slots\n", .{worst});
        return error.ProbesGrew;
    }
    // Every entry that stayed is still found: the rehashes moved them, and
    // lost none.
    try std.testing.expectEqual(@as(usize, resident), map.count());
    var key: usize = 0x1000;
    for (0..resident) |_| {
        try std.testing.expectEqual(@as(?u32, 1), map.get(key));
        key += stride;
    }
}

test "TombstoneGuard: removing while iterating never rehashes under the iterator" {
    var map = std.AutoHashMap(usize, u32).init(std.testing.allocator);
    defer map.deinit();
    var guard: tombstones.TombstoneGuard = .{};
    for (0..1000) |i| {
        guard.beforeInsert(&map);
        try map.put(0x1000 + i * stride, @intCast(i));
    }
    // A teardown sweep: take every entry out as the iterator reaches it.
    var seen: usize = 0;
    var it = map.keyIterator();
    while (it.next()) |key| {
        seen += 1;
        _ = map.remove(key.*);
        guard.noteRemoval(&map);
    }
    try std.testing.expectEqual(@as(usize, 1000), seen);
    try std.testing.expectEqual(@as(usize, 0), map.count());
}

test "TombstoneGuard: a map that grew was rebuilt, and starts counting afresh" {
    var map = std.AutoHashMap(usize, u32).init(std.testing.allocator);
    defer map.deinit();
    var guard: tombstones.TombstoneGuard = .{};
    guard.beforeInsert(&map);
    try map.put(0x1000, 1);
    _ = map.remove(0x1000);
    guard.noteRemoval(&map);
    try std.testing.expectEqual(@as(usize, 1), guard.removals);
    for (0..10_000) |i| try map.put(0x2000 + i * stride, 1);
    guard.beforeInsert(&map);
    try std.testing.expectEqual(@as(usize, 0), guard.removals);
}

test "InstanceRegistry: a page's worth of states registered and released, page after page, leaves half the unused slots free" {
    const State = struct { value: u32 };
    const Registry = webidl.utils.InstanceRegistry(State);
    defer Registry.deinitRegistry();
    var state: State = .{ .value = 1 };

    var next: usize = 0x1000;
    for (0..resident) |_| {
        try Registry.set(@as(*anyopaque, @ptrFromInt(next)), &state);
        next += stride;
    }
    for (0..pages) |page| {
        const first = next;
        for (0..per_page) |i| {
            try Registry.set(@as(*anyopaque, @ptrFromInt(next)), &state);
            next += stride;
            if (i == 0 and page > 0) {
                const counts = tombstones.slotCounts(Registry.ensure());
                if (!counts.halfOfUnusedFree()) {
                    std.debug.print("page {d}: {d} of {d} slots free, {d} live\n", .{ page, counts.free, counts.capacity, counts.live });
                    return error.TombstonesFilledTheTable;
                }
            }
        }
        var key = first;
        while (key < next) : (key += stride) Registry.remove(@as(*anyopaque, @ptrFromInt(key)));
    }
    try std.testing.expectEqual(@as(usize, resident), Registry.count());
}
