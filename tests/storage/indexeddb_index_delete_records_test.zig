const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB delete and clear remove persistent index entries" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "delete-index-records", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndex("by-name", "name", .{});
    for ([_]f64{ 1, 2 }) |number| {
        const request = try store.put("value", idb.IDBKey.number(number));
        request.deinit();
        allocator.destroy(request);
        try index.addEntry(idb.IDBKey.string("name"), idb.IDBKey.number(number));
    }
    const deleted = try store.delete(idb.IDBKeyRange.only(idb.IDBKey.number(1)));
    defer allocator.destroy(deleted);
    defer deleted.deinit();
    try std.testing.expectEqual(@as(usize, 1), index.entriesList().items.len);
    try std.testing.expectEqual(@as(f64, 2), index.entriesList().items[0].primary_key.value.number);
    const cleared = try store.clear();
    defer allocator.destroy(cleared);
    defer cleared.deinit();
    try std.testing.expectEqual(@as(usize, 0), index.entriesList().items.len);
}
