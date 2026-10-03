const std = @import("std");
const idb = @import("storage").indexeddb;

fn expectStoreError(expected: anyerror, duplicate_name: bool, auto_increment: bool) !void {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "empty-store-path", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const existing = try database.createObjectStore("existing", .{});
    defer allocator.destroy(existing);
    defer existing.deinit();

    const unexpected = database.createObjectStore(if (duplicate_name) "existing" else "new", .{
        .compound_key_path = &.{},
        .auto_increment = auto_increment,
    }) catch |err| {
        try std.testing.expectEqual(expected, err);
        return;
    };
    // Free an incorrectly accepted handle before reporting the semantic failure.
    unexpected.deinit();
    allocator.destroy(unexpected);
    return error.TestExpectedError;
}

fn expectIndexError(expected: anyerror, duplicate_name: bool, multi_entry: bool) !void {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "empty-index-path", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    _ = try store.createIndex("existing", "id", .{});

    _ = store.createIndexWithKeyPath(if (duplicate_name) "existing" else "new", .{ .array = &.{} }, .{
        .multi_entry = multi_entry,
    }) catch |err| {
        try std.testing.expectEqual(expected, err);
        return;
    };
    // The store owns every returned index, including an unexpected success.
    return error.TestExpectedError;
}

test "IndexedDB an empty list is not a valid object store key path" {
    try expectStoreError(error.InvalidKeyPathError, false, false);
}

test "IndexedDB invalid store key paths precede duplicate names" {
    try expectStoreError(error.InvalidKeyPathError, true, false);
}

test "IndexedDB invalid store key paths precede autoIncrement restrictions" {
    try expectStoreError(error.InvalidKeyPathError, false, true);
}

test "IndexedDB an empty list is not a valid index key path" {
    try expectIndexError(error.InvalidKeyPathError, false, false);
}

test "IndexedDB duplicate index names precede invalid key paths" {
    try expectIndexError(error.ConstraintError, true, false);
}

test "IndexedDB invalid index key paths precede multiEntry restrictions" {
    try expectIndexError(error.InvalidKeyPathError, false, true);
}

test "IndexedDB a list containing an empty string is a valid key path" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "nonempty-list-path", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("records", .{ .compound_key_path = &.{""} });
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndexWithKeyPath("whole-value", .{ .array = &.{""} }, .{});
    try std.testing.expectEqual(@as(usize, 1), store.compound_key_path.?.len);
    try std.testing.expectEqualStrings("", store.compound_key_path.?[0]);
    try std.testing.expectEqual(@as(usize, 1), index.compound_key_path.?.len);
    try std.testing.expectEqualStrings("", index.compound_key_path.?[0]);
}
