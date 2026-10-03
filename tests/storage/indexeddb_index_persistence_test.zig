const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB index definitions and entries survive transaction handles" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "index-persistence", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const created = try database.createObjectStore("records", .{});
    defer allocator.destroy(created);
    defer created.deinit();
    const write = try created.put("value", idb.IDBKey.number(1));
    defer allocator.destroy(write);
    const index = try created.createIndex("by-key", "key", .{ .unique = true });
    try index.addEntry(idb.IDBKey.string("entry"), idb.IDBKey.number(1));
    try upgrade.commit();
    database.version_change_transaction = null;
    const transaction = try database.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(transaction);
    defer transaction.deinit();
    const store = try transaction.objectStore("records");
    const reopened_index = try store.index("by-key");
    try std.testing.expect(reopened_index.unique);
    try std.testing.expectEqualStrings("key", reopened_index.key_path.?);
    const request = try reopened_index.getKey(idb.IDBKeyRange.only(idb.IDBKey.string("entry")));
    defer allocator.destroy(request);
    try std.testing.expectEqual(@as(f64, 1), request.result.?.key.value.number);
}

test "IndexedDB deleted index handle remains valid native memory" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "deleted-index", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndex("by-key", "key", .{});
    try store.deleteIndex("by-key");
    try std.testing.expectError(error.InvalidStateError, index.count(null));
    try std.testing.expectEqualStrings("by-key", index.name);
    const recreated = try store.createIndex("by-key", "newKey", .{});
    try std.testing.expect(recreated != index);
    try std.testing.expectEqualStrings("key", index.key_path.?);
    try std.testing.expectEqualStrings("newKey", recreated.key_path.?);
}

fn createReopenAndAbort(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "index-definition-allocation", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndex("by-key", "key", .{});
    try index.addEntry(idb.IDBKey.string("entry"), idb.IDBKey.number(1));
    try upgrade.commit();
    database.version_change_transaction = null;
    const transaction = try database.transaction(&.{"records"}, .readwrite, .{});
    defer allocator.destroy(transaction);
    defer transaction.deinit();
    const handle = try transaction.objectStore("records");
    const reopened = try handle.index("by-key");
    try transaction.ensureRollbackSnapshot();
    try reopened.addEntry(idb.IDBKey.string("another"), idb.IDBKey.number(2));
    try transaction.abort();
}

test "IndexedDB persistent index allocation paths unwind snapshots and handles" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, createReopenAndAbort, .{});
}
