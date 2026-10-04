const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB transaction retains native connection after wrapper ownership ends" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "connection-lease", 1);
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    store.deinit();
    allocator.destroy(store);
    database.version_change_transaction = null;
    upgrade.deinit();
    const transaction = try database.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(transaction);
    defer transaction.deinit();
    // GC can destroy both wrappers in either order. Releasing the connection's
    // ownership must preserve the native data until its last transaction ends.
    database.deinit();
    const names = try transaction.db.objectStoreNames();
    defer allocator.free(names);
    try std.testing.expectEqual(@as(usize, 1), names.len);
    try std.testing.expectEqualStrings("records", names[0]);
}
