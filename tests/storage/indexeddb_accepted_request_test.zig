const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB accepted writes execute while the transaction is committing" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "accepted", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{"records"}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    transaction.state = .committing;
    try std.testing.expectError(error.TransactionInactiveError, store.put("rejected", idb.IDBKey.number(1)));
    try transaction.beginRequestExecution();
    defer transaction.endRequestExecution();
    const request = try store.put("accepted", idb.IDBKey.number(1));
    defer allocator.destroy(request);
    defer request.deinit();
    try std.testing.expectEqual(idb.IDBTransactionState.committing, transaction.state);
    try std.testing.expectEqualStrings("accepted", store.recordsList().items[0].value);
}

test "IndexedDB internal abort can roll back a committing transaction" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "commit-abort", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    transaction.state = .committing;
    try std.testing.expectError(error.InvalidStateError, transaction.abort());
    try transaction.abortForError(error.ConstraintError);
    try std.testing.expectEqual(idb.IDBTransactionState.finished, transaction.state);
    try std.testing.expectEqual(error.ConstraintError, transaction.err.?);
    try std.testing.expect(!database.schema().contains("records"));
}

test "IndexedDB an accepted request retains its deleted store and index" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "accepted-deleted", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndex("by-name", "name", .{});
    const write = try store.put("accepted value", idb.IDBKey.number(1));
    write.deinit();
    allocator.destroy(write);
    try index.addEntry(idb.IDBKey.string("accepted key"), idb.IDBKey.number(1));
    try store.deleteIndex("by-name");
    try database.deleteObjectStore("records");
    try std.testing.expectError(error.InvalidStateError, store.get(idb.IDBKeyRange.unbounded()));
    try std.testing.expectError(error.InvalidStateError, index.get(idb.IDBKeyRange.unbounded()));
    transaction.setInactive();
    try transaction.beginRequestExecution();
    defer transaction.endRequestExecution();
    const from_store = try store.get(idb.IDBKeyRange.unbounded());
    defer allocator.destroy(from_store);
    defer from_store.deinit();
    try std.testing.expectEqualStrings("accepted value", from_store.result.?.value);
    const from_index = try index.get(idb.IDBKeyRange.unbounded());
    defer allocator.destroy(from_index);
    defer from_index.deinit();
    try std.testing.expectEqualStrings("accepted value", from_index.result.?.value);
}
