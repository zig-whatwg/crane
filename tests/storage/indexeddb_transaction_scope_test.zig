const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB transaction scope outlives the caller's converted names" {
    const allocator = std.testing.allocator;
    var db = idb.IDBDatabase.init(allocator, "scope", 1);
    defer db.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &db, &.{}, .versionchange);
    defer upgrade.deinit();
    db.version_change_transaction = &upgrade;
    const store = try db.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    db.version_change_transaction = null;
    const name = try allocator.dupe(u8, "records");
    defer allocator.free(name);
    var names = [_][]const u8{name};
    const txn = try db.transaction(&names, .readonly, .{});
    defer allocator.destroy(txn);
    defer txn.deinit();
    name[0] = 'X';
    names[0] = "different";
    try std.testing.expectEqualStrings("records", txn.scope[0]);
}

test "IndexedDB commit algorithm completes an explicitly committing transaction" {
    var db = idb.IDBDatabase.init(std.testing.allocator, "committing", 1);
    defer db.deinit();
    var txn = idb.IDBTransaction.init(std.testing.allocator, &db, &.{}, .readwrite);
    defer txn.deinit();
    // The IDL commit() method sets committing before outstanding requests finish.
    txn.state = .committing;
    try txn.commit();
    try std.testing.expectEqual(idb.IDBTransactionState.finished, txn.state);
}
