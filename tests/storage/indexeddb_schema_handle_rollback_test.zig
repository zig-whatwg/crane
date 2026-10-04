const std = @import("std");
const idb = @import("storage").indexeddb;

fn seed(database: *idb.IDBDatabase) !void {
    var upgrade = idb.IDBTransaction.init(database.allocator, database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    defer database.version_change_transaction = null;
    const store = try database.createObjectStore("old", .{});
    defer database.allocator.destroy(store);
    defer store.deinit();
    _ = try store.createIndex("index", "key", .{});
    try upgrade.commit();
}

test "IndexedDB abort restores deleted old handles and marks replacements deleted" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-handles", 1);
    defer database.deinit();
    try seed(&database);
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const original = try upgrade.objectStore("old");
    const original_index = try original.index("index");
    try original.deleteIndex("index");
    const replaced_index = try original.createIndex("index", "replacement", .{});
    try database.deleteObjectStore("old");
    const temporary = try database.createObjectStore("old", .{ .key_path = "replacement" });
    defer allocator.destroy(temporary);
    defer temporary.deinit();
    const replacement = try upgrade.objectStore("old");
    _ = try replacement.createIndex("new-index", "value", .{});
    try upgrade.abort();
    try std.testing.expect(!original.isDeleted());
    try std.testing.expect(!original_index.deleted);
    try std.testing.expect(replaced_index.deleted);
    try std.testing.expect(replacement.isDeleted());
    const old_names = try original.indexNames();
    defer allocator.free(old_names);
    try std.testing.expectEqual(@as(usize, 1), old_names.len);
    try std.testing.expectEqualStrings("index", old_names[0]);
    const new_names = try replacement.indexNames();
    defer allocator.free(new_names);
    try std.testing.expectEqual(@as(usize, 0), new_names.len);
}

test "IndexedDB a finished handle keeps its index set through later upgrades" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "finished-schema", 1);
    defer database.deinit();
    try seed(&database);
    const read = try database.transaction(&.{"old"}, .readonly, .{});
    defer allocator.destroy(read);
    defer read.deinit();
    const previous = try read.objectStore("old");
    const previous_index = try previous.index("index");
    try read.commit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const current = try upgrade.objectStore("old");
    try current.deleteIndex("index");
    _ = try current.createIndex("later", "later", .{});
    try upgrade.commit();
    const old_names = try previous.indexNames();
    defer allocator.free(old_names);
    try std.testing.expectEqual(@as(usize, 1), old_names.len);
    try std.testing.expectEqualStrings("index", old_names[0]);
    try std.testing.expectEqualStrings("index", previous_index.name);
}
