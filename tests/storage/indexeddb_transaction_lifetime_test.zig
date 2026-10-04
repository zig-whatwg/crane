const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB object-store wrapper lease outlives transaction wrapper" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "transaction-lease", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    database.version_change_transaction = &upgrade;
    const created = try database.createObjectStore("records", .{});
    created.deinit();
    allocator.destroy(created);
    database.version_change_transaction = null;
    upgrade.deinit();
    const transaction = try database.transaction(&.{"records"}, .readonly, .{});
    const store = try transaction.objectStore("records");
    // A store/index/cursor wrapper keeps the native transaction alive even if
    // wrapper graph collection destroys the transaction wrapper first.
    transaction.retain();
    transaction.releaseHeapOwnership();
    try std.testing.expectEqualStrings("records", store.name);
    try std.testing.expectEqual(&database, store.transaction.db);
    transaction.deinit(); // Last wrapper lease also destroys the heap transaction.
}

test "IndexedDB index wrapper lease outlives newly-created store wrapper" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "store-lease", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    const index = try store.createIndex("by-key", "key", .{});
    store.retain();
    store.releaseHeapOwnership();
    try std.testing.expectEqualStrings("by-key", index.name);
    try std.testing.expectEqualStrings("records", index.object_store.name);
    store.deinit();
}
