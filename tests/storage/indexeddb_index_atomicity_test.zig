const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB unique failure leaves earlier indexes unchanged" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "atomic-indexes", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var indexes = [_]idb.IDBIndex{
        idb.IDBIndex.init(allocator, "first", &store),
        idb.IDBIndex.init(allocator, "unique", &store),
    };
    defer for (&indexes) |*index| index.deinit();
    indexes[0].key_path = "key";
    indexes[1].key_path = "key";
    indexes[1].unique = true;
    try indexes[1].addEntry(idb.IDBKey.string("duplicate"), idb.IDBKey.number(1));
    const properties = [_]idb.ExtractedValue.Property{.{ .key = "key", .value = .{ .string = "duplicate" } }};
    try std.testing.expectError(error.ConstraintError, idb.updateIndexesForRecord(allocator, &indexes, .{ .object = &properties }, idb.IDBKey.number(2)));
    try std.testing.expectEqual(@as(usize, 0), indexes[0].entriesList().items.len);
    try std.testing.expectEqual(@as(usize, 1), indexes[1].entriesList().items.len);
}

test "IndexedDB multiEntry constraint failure publishes no partial subkeys" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "atomic-subkeys", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "unique", &store);
    defer index.deinit();
    index.unique = true;
    try index.addEntry(idb.IDBKey.string("duplicate"), idb.IDBKey.number(1));
    const keys = [_]idb.IDBKey{ idb.IDBKey.string("new"), idb.IDBKey.string("duplicate") };
    try std.testing.expectError(error.ConstraintError, idb.addIndexEntries(&index, .{ .multi_keys = &keys }, idb.IDBKey.number(2)));
    try std.testing.expectEqual(@as(usize, 1), index.entriesList().items.len);
}

test "IndexedDB indexes order equal index keys by primary key" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "index-order", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readonly);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "by-key", &store);
    defer index.deinit();
    try index.addEntry(idb.IDBKey.string("same"), idb.IDBKey.number(9));
    try index.addEntry(idb.IDBKey.string("same"), idb.IDBKey.number(1));
    const request = try index.getKey(idb.IDBKeyRange.only(idb.IDBKey.string("same")));
    defer allocator.destroy(request);
    try std.testing.expectEqual(@as(f64, 1), request.result.?.key.value.number);
    const cursor_request = try index.openCursor(null, .prevunique);
    defer allocator.destroy(cursor_request);
    const cursor = cursor_request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    try std.testing.expectEqual(@as(f64, 1), cursor.primary_key.?.value.number);
}

fn updateAllocationWalk(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "atomic-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var indexes = [_]idb.IDBIndex{
        idb.IDBIndex.init(allocator, "first", &store),
        idb.IDBIndex.init(allocator, "second", &store),
    };
    defer for (&indexes) |*index| index.deinit();
    for (&indexes) |*index| index.key_path = "key";
    const properties = [_]idb.ExtractedValue.Property{.{ .key = "key", .value = .{ .string = "entry" } }};
    idb.updateIndexesForRecord(allocator, &indexes, .{ .object = &properties }, idb.IDBKey.string("primary")) catch |err| {
        for (&indexes) |*index| try std.testing.expectEqual(@as(usize, 0), index.entriesList().items.len);
        return err;
    };
    for (&indexes) |*index| try std.testing.expectEqual(@as(usize, 1), index.entriesList().items.len);
}

test "IndexedDB index allocation failure publishes no partial update" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, updateAllocationWalk, .{});
}
