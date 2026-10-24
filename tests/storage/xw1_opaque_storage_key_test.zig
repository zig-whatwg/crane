//! A missing opaque identity is never a shared storage partition.
const std = @import("std");
const storage = @import("storage");
const testing = std.testing;

test "xw1 null serializations alone never identify the same origin" {
    const a = storage.StorageKey.initBorrowed("null", "https://top.test", true);
    const b = storage.StorageKey.initBorrowed("null", "https://top.test", true);
    try testing.expect(!a.equals(b));
    try testing.expect(storage.obtainStorageKey(a) == null);
}

test "xw1 tuple storage keys retain their canonical bytes" {
    const a = storage.StorageKey.initBorrowed("https://a.test", "https://top.test", true);
    const serialized = try a.serialize(testing.allocator);
    defer testing.allocator.free(serialized);
    try testing.expectEqualStrings("https://a.test https://top.test 1", serialized);
    const parsed = storage.StorageKey.parse(serialized).?;
    try testing.expect(a.equals(parsed));
    try testing.expectEqual(a.hash(), parsed.hash());
}

test "xw1 opaque keys preserve identity through clone serialization and hashing but cannot persist" {
    try testing.expect(@hasField(storage.StorageKey, "origin_nonce"));
    if (comptime !@hasField(storage.StorageKey, "origin_nonce")) return;
    var a = storage.StorageKey.initBorrowed("null", "null", false);
    a.origin_nonce = 12;
    a.top_level_nonce = 34;
    const bytes = try a.serialize(testing.allocator);
    defer testing.allocator.free(bytes);
    const parsed = storage.StorageKey.parse(bytes).?;
    var copy = try parsed.clone(testing.allocator);
    defer copy.deinit();
    try testing.expect(a.equals(copy));
    try testing.expectEqual(a.hash(), copy.hash());
    try testing.expect(storage.obtainStorageKey(copy) == null);
    copy.origin_nonce = 13;
    try testing.expect(!a.equals(copy));
    copy.origin_nonce = 12;
    copy.top_level_nonce = 35;
    try testing.expect(!a.equals(copy));
    copy.top_level_nonce = null;
    try testing.expect(!a.equals(copy));
}

test "xw1 origin-only administrative shelf keys remain findable and separate from environment partitions" {
    // UserAgentStorage.obtainShelfLocked deliberately uses an empty site for
    // its origin-only administrative shelf, never a real environment's key.
    const administrative = storage.StorageKey.initBorrowed("https://a.test", "", false);
    var copy = try administrative.clone(testing.allocator);
    defer copy.deinit();
    try testing.expect(administrative.equals(copy));
    try testing.expectEqual(administrative.hash(), copy.hash());

    var map = std.HashMap(storage.StorageKey, u8, storage.StorageKey.HashContext, std.hash_map.default_max_load_percentage).init(testing.allocator);
    defer map.deinit();
    try map.put(administrative, 1);
    try testing.expectEqual(@as(u8, 1), map.get(copy) orelse return error.AdministrativeShelfMissing);
    const partition = storage.StorageKey.initBorrowed("https://a.test", "https://a.test", false);
    const other_origin = storage.StorageKey.initBorrowed("https://b.test", "", false);
    const other_ancestor = storage.StorageKey.initBorrowed("https://a.test", "", true);
    try map.put(partition, 2);
    try map.put(other_origin, 3);
    try map.put(other_ancestor, 4);
    try testing.expectEqual(@as(u32, 4), map.count());
    try testing.expectEqual(@as(u8, 1), map.get(copy).?);
    try testing.expect(!administrative.equals(partition));
    try testing.expect(!administrative.equals(other_origin));
    try testing.expect(!administrative.equals(other_ancestor));
    // The internal sentinel does not become a usable environment key.
    try testing.expect(storage.obtainStorageKey(administrative) == null);
    try testing.expect(storage.StorageKey.parse("https://a.test  0") == null);
}

test "xw1 an administrative empty-site sentinel never supplies a missing opaque identity" {
    const missing_origin = storage.StorageKey.initBorrowed("", "", false);
    try testing.expect(!missing_origin.equals(missing_origin));
    var opaque_origin = storage.StorageKey.initBorrowed("null", "", false);
    try testing.expect(!opaque_origin.equals(opaque_origin));
    opaque_origin.origin_nonce = 19;
    try testing.expect(!opaque_origin.equals(opaque_origin));
    var opaque_top = storage.StorageKey.initBorrowed("https://a.test", "null", false);
    try testing.expect(!opaque_top.equals(opaque_top));
    opaque_top.top_level_nonce = 0;
    try testing.expect(!opaque_top.equals(opaque_top));
}

test "xw1 every key admitted to a storage shed is reflexive and stays findable after cloning" {
    var shed = storage.StorageShed.init(testing.allocator, .local);
    defer shed.deinit();
    const keys = [_]storage.StorageKey{
        storage.StorageKey.initBorrowed("https://a.test", "https://top.test", false),
        storage.StorageKey.initBorrowed("https://a.test", "https://top.test", true),
        storage.StorageKey.initBorrowed("https://a.test", "", false),
        storage.StorageKey.initBorrowed("https://a.test", "", true),
    };
    for (keys) |key| {
        try testing.expect(key.equals(key));
        var copy = try key.clone(testing.allocator);
        defer copy.deinit();
        try testing.expect(key.equals(copy));
        try testing.expectEqual(key.hash(), copy.hash());
        const shelf = try shed.obtainShelf(key);
        try testing.expectEqual(shelf, shed.getShelf(copy).?);
        try testing.expectEqual(shelf, try shed.obtainShelf(copy));
    }
    try testing.expectEqual(@as(u32, keys.len), shed.shelves.count());
}

test "xw1 a storage shed rejects opaque or missing partition identities before inserting" {
    var shed = storage.StorageShed.init(testing.allocator, .local);
    defer shed.deinit();
    var identified_opaque = storage.StorageKey.initBorrowed("null", "null", false);
    identified_opaque.origin_nonce = 17;
    identified_opaque.top_level_nonce = 31;
    const keys = [_]storage.StorageKey{
        storage.StorageKey.initBorrowed("", "https://top.test", false),
        storage.StorageKey.initBorrowed("null", "https://top.test", false),
        storage.StorageKey.initBorrowed("https://a.test", "null", false),
        storage.StorageKey.initBorrowed("null", "", false),
        identified_opaque,
    };
    for (keys) |key| {
        try testing.expectError(error.SecurityError, shed.obtainShelf(key));
        try testing.expectEqual(@as(u32, 0), shed.shelves.count());
    }
}

test "xw1 the IndexedDB server refuses invalid storage keys before inserting" {
    var identified_opaque = storage.StorageKey.initBorrowed("null", "null", false);
    identified_opaque.origin_nonce = 17;
    identified_opaque.top_level_nonce = 31;
    const keys = [_]storage.StorageKey{
        storage.StorageKey.initBorrowed("", "https://top.test", false),
        storage.StorageKey.initBorrowed("null", "https://top.test", false),
        storage.StorageKey.initBorrowed("https://a.test", "null", false),
        storage.StorageKey.initBorrowed("https://a.test", "", false),
        identified_opaque,
    };
    for (keys) |key| {
        var server = storage.indexeddb.IDBServer.init(testing.allocator);
        defer server.deinit();
        try testing.expectError(error.SecurityError, server.uniqueDatabase(key, "invalid"));
        try testing.expectEqual(@as(u32, 0), server.databases.count());
    }
}

test "xw1 the IndexedDB server reuses a valid partition key after cloning" {
    var server = storage.indexeddb.IDBServer.init(testing.allocator);
    defer server.deinit();
    const key = storage.StorageKey.initBorrowed("https://a.test", "https://top.test", true);
    var copy = try key.clone(testing.allocator);
    defer copy.deinit();
    try testing.expect(key.equals(key));
    try testing.expectEqual(key.hash(), copy.hash());
    {
        const first = try server.uniqueDatabase(key, "valid");
        defer server.release(first);
        const second = try server.uniqueDatabase(copy, "valid");
        defer server.release(second);
        try testing.expectEqual(first, second);
        try testing.expectEqual(@as(u32, 1), server.databases.count());
    }
    // Releasing the last holder finds and removes the same map key.
    try testing.expectEqual(@as(u32, 0), server.databases.count());
}
