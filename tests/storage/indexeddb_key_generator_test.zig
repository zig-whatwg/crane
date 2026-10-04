const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB generator advances after fractional and infinite numeric keys" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "generator", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    store.auto_increment = true;
    const fractional = try store.put("fractional", idb.IDBKey.number(7.25));
    defer allocator.destroy(fractional);
    try std.testing.expectEqual(@as(u64, 8), store.getCurrentKeyGeneratorValue());
    const next = try store.put("generated", null);
    defer allocator.destroy(next);
    try std.testing.expectEqual(@as(f64, 8), next.result.?.key.value.number);
    const infinite = try store.put("infinite", idb.IDBKey.number(std.math.inf(f64)));
    defer allocator.destroy(infinite);
    try std.testing.expectError(error.ConstraintError, store.put("exhausted", null));
}
