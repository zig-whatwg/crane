//! Side tables keyed by an object's address stay fast when page after page of
//! entries comes and goes (src/infra/tombstones.zig, re-exported as webidl.utils.tombstones).
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

// InstanceRegistry's own churn test: tests/runtime/instance_registry_test.zig
// (runtime.InstanceRegistry, a Browser's side table, since instances B1).

// ---------------------------------------------------------------------------
// Unmanaged maps (lane hashmaps1): most of Crane's long-lived maps are
// `*HashMapUnmanaged` - the wrapper cache's side maps, the HTTP cache, the
// preflight cache, IndexedDB's databases - so the guard and the diagnostics
// take either kind.
// ---------------------------------------------------------------------------

/// The same runner churn as `churn`, over an unmanaged map.
fn churnUnmanaged(map: *std.AutoHashMapUnmanaged(usize, u32), guard: ?*tombstones.TombstoneGuard) !void {
    const allocator = std.testing.allocator;
    var next: usize = 0x1000;
    for (0..resident) |_| {
        if (guard) |g| g.beforeInsert(map);
        try map.put(allocator, next, 1);
        next += stride;
    }
    for (0..pages) |_| {
        const first = next;
        for (0..per_page) |_| {
            if (guard) |g| g.beforeInsert(map);
            try map.put(allocator, next, 2);
            next += stride;
        }
        var key = first;
        while (key < next) : (key += stride) {
            if (map.remove(key)) {
                if (guard) |g| g.noteRemoval(map);
            }
        }
    }
}

test "slotCounts and meanMissProbe read an unmanaged map: unguarded churn leaves no free slot to stop a miss" {
    var map: std.AutoHashMapUnmanaged(usize, u32) = .empty;
    defer map.deinit(std.testing.allocator);
    try churnUnmanaged(&map, null);
    const counts = tombstones.slotCounts(&map);
    try std.testing.expectEqual(@as(usize, resident), counts.live);
    try std.testing.expect(!counts.halfOfUnusedFree());
    // A miss walks from its home slot to the first free one: with the free
    // slots gone, most of the table.
    try std.testing.expect(tombstones.meanMissProbe(&map) > counts.capacity / 8);
}

test "TombstoneGuard keeps an unmanaged map's misses short" {
    var map: std.AutoHashMapUnmanaged(usize, u32) = .empty;
    defer map.deinit(std.testing.allocator);
    var guard: tombstones.TombstoneGuard = .{};
    try churnUnmanaged(&map, &guard);
    // The invariant holds at an insert: the next page's first one.
    guard.beforeInsert(&map);
    const counts = tombstones.slotCounts(&map);
    try std.testing.expect(counts.halfOfUnusedFree());
    try std.testing.expect(tombstones.meanMissProbe(&map) <= 8);
    var key: usize = 0x1000;
    for (0..resident) |_| {
        try std.testing.expectEqual(@as(?u32, 1), map.get(key));
        key += stride;
    }
}

/// A custom stateless context, as the HTTP and preflight caches have.
const PairContext = struct {
    pub fn hash(_: PairContext, key: [2]u32) u64 {
        return std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
    }
    pub fn eql(_: PairContext, a: [2]u32, b: [2]u32) bool {
        return a[0] == b[0] and a[1] == b[1];
    }
};

test "TombstoneGuard rehashes an unmanaged map with a custom stateless context, and a StringHashMap" {
    const allocator = std.testing.allocator;
    var pairs: std.HashMapUnmanaged([2]u32, u32, PairContext, 80) = .empty;
    defer pairs.deinit(allocator);
    var strings = std.StringHashMap(u32).init(allocator);
    defer strings.deinit();
    var names: std.ArrayList([]u8) = .empty;
    defer {
        for (names.items) |name| allocator.free(name);
        names.deinit(allocator);
    }
    var pair_guard: tombstones.TombstoneGuard = .{};
    var string_guard: tombstones.TombstoneGuard = .{};
    for (0..200) |round| {
        for (0..64) |i| {
            const n: u32 = @intCast(round * 64 + i);
            pair_guard.beforeInsert(&pairs);
            try pairs.put(allocator, .{ n, n *% 7 }, n);
            const name = try std.fmt.allocPrint(allocator, "id-{d}", .{n});
            try names.append(allocator, name);
            string_guard.beforeInsert(&strings);
            try strings.put(name, n);
        }
        for (0..64) |i| {
            const n: u32 = @intCast(round * 64 + i);
            if (pairs.remove(.{ n, n *% 7 })) pair_guard.noteRemoval(&pairs);
            if (strings.remove(names.items[n])) string_guard.noteRemoval(&strings);
        }
    }
    pair_guard.beforeInsert(&pairs);
    string_guard.beforeInsert(&strings);
    try std.testing.expect(tombstones.slotCounts(&pairs).halfOfUnusedFree());
    try std.testing.expect(tombstones.slotCounts(&strings).halfOfUnusedFree());
}

test "meanMissProbe: an empty map is 0; a map that never removed probes about as far as its load says" {
    var map = std.AutoHashMap(usize, u32).init(std.testing.allocator);
    defer map.deinit();
    try std.testing.expectEqual(@as(usize, 0), tombstones.meanMissProbe(&map));
    for (0..1000) |i| try map.put(0x1000 + i * stride, 1);
    // At most 80% full with linear probing: a few slots, never the table.
    try std.testing.expect(tombstones.meanMissProbe(&map) < 16);
}
