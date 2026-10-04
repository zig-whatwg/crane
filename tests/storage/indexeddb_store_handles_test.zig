const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB recreated store has a new transaction handle" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "store-handles", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const created = try database.createObjectStore("records", .{});
    defer allocator.destroy(created);
    defer created.deinit();
    const original = try transaction.objectStore("records");
    try std.testing.expectEqual(original, try transaction.objectStore("records"));
    try database.deleteObjectStore("records");
    try std.testing.expectError(error.NotFoundError, transaction.objectStore("records"));
    const recreated = try database.createObjectStore("records", .{ .auto_increment = true });
    defer allocator.destroy(recreated);
    defer recreated.deinit();
    const replacement = try transaction.objectStore("records");
    try std.testing.expect(original != replacement);
    try std.testing.expect(replacement.auto_increment);
    try std.testing.expectEqualStrings("records", original.name);
}

test "IndexedDB deleted store handle rejects native operations" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "deleted-handle", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const created = try database.createObjectStore("records", .{});
    defer allocator.destroy(created);
    defer created.deinit();
    const store = try transaction.objectStore("records");
    try database.deleteObjectStore("records");
    const result = store.clear();
    // Free an unexpected request, so the semantic red does not mask a leak.
    if (result) |request| {
        request.deinit();
        allocator.destroy(request);
    } else |_| {}
    try std.testing.expectError(error.InvalidStateError, result);
}
