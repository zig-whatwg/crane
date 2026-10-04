const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB completed native requests leave no dangling list entry" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "request-list", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{"records"}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const put = try store.put("value", idb.IDBKey.number(1));
    try std.testing.expectEqual(@as(usize, 1), transaction.requests.items.len);
    put.deinit();
    allocator.destroy(put);
    try std.testing.expectEqual(@as(usize, 0), transaction.requests.items.len);
    const get = try store.get(idb.IDBKeyRange.only(idb.IDBKey.number(1)));
    get.deinit();
    allocator.destroy(get);
    try std.testing.expectEqual(@as(usize, 0), transaction.requests.items.len);
}
