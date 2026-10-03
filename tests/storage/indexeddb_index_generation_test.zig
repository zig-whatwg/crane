const std = @import("std");
const idb = @import("storage").indexeddb;
const kp = idb.key_path;
const kg = idb.index_keygen;

test "IndexedDB generated array index key owns its storage" {
    const values = [_]kp.ExtractedValue{ .{ .number = 1 }, .{ .string = "value" } };
    const properties = [_]kp.ExtractedValue.Property{.{ .key = "key", .value = .{ .array = &values } }};
    const result = try kg.generateIndexKey(std.testing.allocator, .{ .object = &properties }, .{ .key_path = .{ .single = "key" } });
    switch (result) {
        .single_key => |generated| {
            var key = generated;
            defer key.deinit();
            try std.testing.expect(key.allocator != null);
            try std.testing.expectEqualStrings("value", key.value.array[1].value.string);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "IndexedDB index key generator retains nested multiEntry subkeys" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "index-nested", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "nested", &store);
    defer index.deinit();
    index.multi_entry = true;
    const inner = [_]idb.IDBKey{ idb.IDBKey.number(1), idb.IDBKey.number(2) };
    const subkeys = [_]idb.IDBKey{idb.IDBKey.array(&inner)};
    try kg.addIndexEntries(&index, .{ .multi_keys = &subkeys }, idb.IDBKey.number(4));
    try std.testing.expectEqual(@as(usize, 1), index.entries.items.len);
    try std.testing.expectEqual(idb.key.IDBKeyType.array, index.entries.items[0].index_key.key_type);
}

test "IndexedDB native index extracts nested multiEntry subkeys" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "index-extraction", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "nested", &store);
    defer index.deinit();
    index.key_path = "tags";
    index.multi_entry = true;
    const inner = [_]kp.ExtractedValue{ .{ .number = 1 }, .{ .number = 2 } };
    const elements = [_]kp.ExtractedValue{.{ .array = &inner }};
    const properties = [_]kp.ExtractedValue.Property{.{ .key = "tags", .value = .{ .array = &elements } }};
    try index.addEntriesForValue(allocator, .{ .object = &properties }, idb.IDBKey.number(4));
    try std.testing.expectEqual(@as(usize, 1), index.entries.items.len);
}
