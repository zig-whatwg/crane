//! runtime.native_timer.TimerIdMap (lane timerheap1): the map keyed by timer
//! id behind the manager's armed timers, a window's map of active timers and
//! a worker global's. It rehashes away its tombstones (TombstoneGuard) and
//! rebuilds itself smaller once fewer than a sixth of its slots are in use
//! (WTF HashTable's minLoad) - both only before an insert, never on removal
//! or during a walk, since owners remove entries while they walk the map.

const std = @import("std");
const runtime = @import("runtime");
const tombstones = @import("webidl").utils.tombstones;
const testing = std.testing;

const TimerId = runtime.TimerId;
const Map = runtime.native_timer.TimerIdMap(u64);

/// A value that names its key, so a lost or crossed entry shows.
fn valueOf(id: TimerId) u64 {
    return id *% 0x9e3779b97f4a7c15;
}

fn armNew(map: *Map, next: *TimerId) !TimerId {
    try map.ensureUnusedCapacity(testing.allocator, 1);
    const id = next.*;
    next.* += 1;
    map.putAssumeCapacityNoClobber(id, valueOf(id));
    return id;
}

test "entries removed while the map is walked, then an insert that rebuilds it: nothing lost, nothing seen twice" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    for (0..5_000) |_| _ = try armNew(&map, &next);
    const big = map.capacity();

    // A walk that removes as it goes, as a window's end and a worker's
    // termination do: every entry is seen exactly once, and three in four
    // leave - some of them ahead of the walk.
    var seen = std.AutoHashMap(TimerId, void).init(testing.allocator);
    defer seen.deinit();
    var walk = map.iterator();
    while (walk.next()) |kv| {
        const id = kv.key_ptr.*;
        try testing.expectEqual(valueOf(id), kv.value_ptr.*);
        try testing.expect(!seen.contains(id));
        try seen.put(id, {});
        if (id % 4 != 0) _ = map.remove(id);
        // One not yet reached, if still there: removed ahead of the walk.
        if (id % 4 == 0 and id + 4 < next) _ = map.remove(id + 3);
    }
    // No removal rebuilt the map under the walk.
    try testing.expectEqual(big, map.capacity());

    // Every entry not removed by the walk is still there.
    var kept: usize = 0;
    for (1..next) |id| {
        if (id % 4 == 0) {
            try testing.expectEqual(@as(?u64, valueOf(id)), map.get(id));
            kept += 1;
        }
    }
    try testing.expectEqual(kept, map.count());

    // Clear all but a few, then insert: the insert rebuilds the table
    // smaller, and every survivor and the new entry are found.
    var it = map.keyIterator();
    var doomed: std.ArrayListUnmanaged(TimerId) = .empty;
    defer doomed.deinit(testing.allocator);
    while (it.next()) |id| if (id.* > 40) try doomed.append(testing.allocator, id.*);
    for (doomed.items) |id| try testing.expect(map.remove(id));
    const survivors = map.count();
    try testing.expectEqual(big, map.capacity());
    const fresh = try armNew(&map, &next);
    try testing.expect(map.capacity() < big);
    try testing.expectEqual(survivors + 1, map.count());
    for ([_]TimerId{ 4, 8, 12, 16, 20, 24, 28, 32, 36, 40 }) |id| try testing.expectEqual(@as(?u64, valueOf(id)), map.get(id));
    try testing.expectEqual(@as(?u64, valueOf(fresh)), map.get(fresh));
    // The rebuilt table has no tombstones, and the guard knows it.
    try testing.expectEqual(@as(usize, 0), map.guard.removals);
    const counts = tombstones.slotCounts(&map.map);
    try testing.expectEqual(counts.capacity - counts.live, counts.free);
}

test "a burst of 5,000 gives its slots back at the next inserts, at least halving each time, and no further than 64" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    const resident = try armNew(&map, &next);
    var ids: [5_000]TimerId = undefined;
    for (&ids) |*id| id.* = try armNew(&map, &next);
    try testing.expectEqual(@as(Map.Size, 8_192), map.capacity());
    for (ids) |id| try testing.expect(map.remove(id));
    // Removals give nothing back by themselves.
    try testing.expectEqual(@as(Map.Size, 8_192), map.capacity());

    var last = map.capacity();
    var rebuilds: usize = 0;
    for (0..16) |_| {
        try testing.expect(map.remove(try armNew(&map, &next)));
        if (map.capacity() != last) {
            try testing.expect(map.capacity() * 2 <= last);
            rebuilds += 1;
            last = map.capacity();
        }
    }
    try testing.expectEqual(@as(Map.Size, 64), map.capacity());
    try testing.expectEqual(@as(usize, 1), rebuilds);
    try testing.expectEqual(@as(?u64, valueOf(resident)), map.get(resident));
}

test "a map whose size sits at the shrink threshold is rebuilt once, not on every insert" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    var live: std.ArrayListUnmanaged(TimerId) = .empty;
    defer live.deinit(testing.allocator);
    while (live.items.len < 300) try live.append(testing.allocator, try armNew(&map, &next));
    try testing.expectEqual(@as(Map.Size, 512), map.capacity());
    // 85 of 512 is below a sixth.
    while (live.items.len > 85) try testing.expect(map.remove(live.pop().?));
    var changes: usize = 0;
    var last = map.capacity();
    for (0..1_000) |_| {
        try live.append(testing.allocator, try armNew(&map, &next));
        try testing.expect(map.remove(live.pop().?));
        if (map.capacity() != last) changes += 1;
        last = map.capacity();
    }
    // Rebuilt for twice its entries, it is far from both edges: the next
    // shrink needs the count to fall by more than half again, the next
    // growth needs it to double.
    try testing.expectEqual(@as(usize, 1), changes);
    try testing.expectEqual(@as(Map.Size, 256), map.capacity());
    for (live.items) |id| try testing.expectEqual(@as(?u64, valueOf(id)), map.get(id));
}

test "room made by ensureUnusedCapacity survives a removal before the insert" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    var ids: [2_000]TimerId = undefined;
    for (&ids) |*id| id.* = try armNew(&map, &next);
    for (ids[1..]) |id| try testing.expect(map.remove(id));
    // WorkerHost.setTimer: room first, then the timer is armed and an id
    // taken, then the insert; a removal in between must not take the room.
    try map.ensureUnusedCapacity(testing.allocator, 1);
    const cap = map.capacity();
    try testing.expect(map.remove(ids[0]));
    try testing.expectEqual(cap, map.capacity());
    map.putAssumeCapacityNoClobber(next, valueOf(next));
    try testing.expectEqual(@as(?u64, valueOf(next)), map.get(next));
}

test "timers that come and go keep half the unused slots free across rebuilds" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    const resident = try armNew(&map, &next);
    var starved: usize = 0;
    for (0..300) |round| {
        // Every tenth round a burst of 1,000 that comes and goes.
        const width: usize = if (round % 10 == 0) 1_000 else 48;
        var burst: std.ArrayListUnmanaged(TimerId) = .empty;
        defer burst.deinit(testing.allocator);
        for (0..width) |i| {
            try burst.append(testing.allocator, try armNew(&map, &next));
            if (i == 0 and !tombstones.slotCounts(&map.map).halfOfUnusedFree()) starved += 1;
        }
        for (burst.items) |id| try testing.expect(map.remove(id));
        for (0..64) |_| try testing.expect(map.remove(try armNew(&map, &next)));
    }
    try testing.expectEqual(@as(usize, 0), starved);
    try testing.expectEqual(@as(?u64, valueOf(resident)), map.get(resident));
    try testing.expectEqual(@as(Map.Size, 1), map.count());
}

test "clearRetainingCapacity empties the map and the next insert gives the slots back" {
    var map: Map = .empty;
    defer map.deinit(testing.allocator);
    var next: TimerId = 1;
    for (0..3_000) |_| _ = try armNew(&map, &next);
    map.clearRetainingCapacity();
    try testing.expectEqual(@as(Map.Size, 0), map.count());
    _ = try armNew(&map, &next);
    try testing.expectEqual(@as(Map.Size, 64), map.capacity());
    try testing.expectEqual(@as(Map.Size, 1), map.count());
}
