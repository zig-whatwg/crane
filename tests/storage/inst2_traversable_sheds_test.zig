//! A Browser's traversable storage sheds (storage.TraversableStorageSheds,
//! Storage 4.3): each traversable's own, made on first use, ended with the
//! traversable (`discard`, from BrowsingContext.deinit) - and a Browser that
//! opens and closes many tabs keeps a small map (lane inst2).
const std = @import("std");
const testing = std.testing;
const storage = @import("storage");
const infra = @import("infra");

const StorageKey = storage.StorageKey;
const key = StorageKey.initBorrowed("https://inst2.test", "https://inst2.test", false);

test "a traversable's shed ends with it; another traversable's stays" {
    var sheds = storage.TraversableStorageSheds.init(testing.allocator);
    defer sheds.deinit();
    for ([_]u64{ 1, 2 }) |traversable| {
        const map = (try storage.obtainSessionStorageBottleMap(&sheds, traversable, key, .sessionStorage)) orelse return error.TestUnexpectedNull;
        try map.set("k", "a value the shed owns");
    }
    try testing.expectEqual(@as(usize, 2), sheds.count());

    sheds.discard(1);
    try testing.expect(!sheds.contains(1));
    const kept = (try storage.obtainSessionStorageBottleMap(&sheds, 2, key, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try testing.expectEqualStrings("a value the shed owns", kept.get("k").?);

    // A traversable that never had one - a frame's context - is nothing to
    // discard; nor is one already gone.
    sheds.discard(99);
    sheds.discard(1);
    try testing.expectEqual(@as(usize, 1), sheds.count());

    // A traversable discarded and asked again starts empty (ids are never
    // reused by browsing contexts; this pins the shed, not the ids).
    const fresh = (try storage.obtainSessionStorageBottleMap(&sheds, 1, key, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try testing.expect(fresh.get("k") == null);
}

test "ten thousand tabs opened and closed one after another leave a small map" {
    var sheds = storage.TraversableStorageSheds.init(testing.allocator);
    defer sheds.deinit();
    // The host's tab lives throughout.
    _ = try sheds.shedOf(1);
    var traversable: u64 = 2;
    while (traversable < 10_002) : (traversable += 1) {
        const map = (try storage.obtainSessionStorageBottleMap(&sheds, traversable, key, .sessionStorage)) orelse return error.TestUnexpectedNull;
        try map.set("k", "v");
        sheds.discard(traversable);
    }
    try testing.expectEqual(@as(usize, 1), sheds.count());
    // The next tab's shed: its insert rehashes the tombstones away when they
    // could take half the slots not in use (infra.tombstones.TombstoneGuard),
    // so at least half of those are free and a lookup that misses stops
    // early. Unguarded, 10,000 removals leave every unused slot a tombstone,
    // and every miss walks the whole table.
    _ = try sheds.shedOf(20_000);
    const counts = infra.tombstones.slotCounts(&sheds.sheds);
    try testing.expect(counts.halfOfUnusedFree());
    try testing.expect(counts.capacity <= 16);
}

test "a published copy is the new traversable's, and discarding it leaves the source" {
    var sheds = storage.TraversableStorageSheds.init(testing.allocator);
    defer sheds.deinit();
    const source = (try storage.obtainSessionStorageBottleMap(&sheds, 1, key, .sessionStorage)) orelse return error.TestUnexpectedNull;
    try source.set("k", "source");
    try sheds.publish(2, storage.StorageShed.init(testing.allocator, .session));
    try testing.expect(sheds.contains(2));
    sheds.discard(2);
    try testing.expect(!sheds.contains(2));
    try testing.expectEqualStrings("source", source.get("k").?);
}
