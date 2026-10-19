//! A readwrite transaction's rollback snapshot (IndexedDB 5.5 step 2)
//! copies only the stores in its scope. Another store's records may belong
//! to another transaction while this one runs - ED 2.7.2 lets transactions
//! with disjoint scopes run at once - and with IndexedDB storage shared per
//! Browser, that other transaction may be on another thread: copying its
//! store would read records it is writing, and restoring them would undo
//! its writes.
//!
//! tests/storage is one executable: nothing here assumes it runs first.

const std = @import("std");
const idb = @import("storage").indexeddb;

fn addStores(database: *idb.IDBDatabase, names: []const []const u8) !void {
    var upgrade = idb.IDBTransaction.init(std.testing.allocator, database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    defer database.version_change_transaction = null;
    for (names) |name| {
        const store = try database.createObjectStore(name, .{});
        store.deinit();
        std.testing.allocator.destroy(store);
    }
    try upgrade.commit();
}

fn put(store: *idb.IDBObjectStore, key: f64) !void {
    const request = try store.put("value", idb.IDBKey.number(key));
    request.deinit();
    std.testing.allocator.destroy(request);
}

test "IndexedDB a readwrite transaction's rollback snapshot holds only the stores in its scope" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-scope", 1);
    defer database.deinit();
    try addStores(&database, &.{ "a", "b" });
    const transaction = try database.transaction(&.{"a"}, .readwrite, .{});
    defer {
        transaction.deinit();
        allocator.destroy(transaction);
    }
    try put(try transaction.objectStore("a"), 1);
    const snapshot = transaction.rollback_schema orelse return error.TestExpectedSnapshot;
    try std.testing.expectEqual(@as(u32, 1), snapshot.count());
    try std.testing.expect(snapshot.contains("a"));
    try std.testing.expect(!snapshot.contains("b"));
    try transaction.abort();
}
