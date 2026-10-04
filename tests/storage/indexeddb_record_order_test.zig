const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB retrieval selects the lowest key independent of insertion order" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "record-order", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const keys = [_]f64{ 9, 1, 5 };
    for (keys) |key| {
        const request = try store.put("value", idb.IDBKey.number(key));
        allocator.destroy(request);
    }
    const request = try store.getKey(idb.IDBKeyRange.unbounded());
    defer allocator.destroy(request);
    try std.testing.expectEqual(@as(f64, 1), request.result.?.key.value.number);
    try std.testing.expectEqual(@as(f64, 1), store.recordsList().items[0].key.value.number);
    try std.testing.expectEqual(@as(f64, 5), store.recordsList().items[1].key.value.number);
    try std.testing.expectEqual(@as(f64, 9), store.recordsList().items[2].key.value.number);
}
