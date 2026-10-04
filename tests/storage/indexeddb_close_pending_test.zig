const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB close marks pending and allows accepted transactions to finish" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "close-pending", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    try upgrade.commit();
    database.version_change_transaction = null;
    const transaction = try database.transaction(&.{"records"}, .readwrite, .{});
    defer allocator.destroy(transaction);
    defer transaction.deinit();
    database.close();
    try std.testing.expect(database.closed);
    try std.testing.expectEqual(idb.IDBTransactionState.active, transaction.state);
    try std.testing.expectError(error.InvalidStateError, database.transaction(&.{"records"}, .readonly, .{}));
    try transaction.commit();
}
