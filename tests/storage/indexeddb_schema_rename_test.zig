const std = @import("std");
const idb = @import("storage").indexeddb;

fn renameAndAbort(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "rename", 1);
    defer database.deinit();
    var initial = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer initial.deinit();
    database.version_change_transaction = &initial;
    const temporary = try database.createObjectStore("before", .{});
    defer allocator.destroy(temporary);
    defer temporary.deinit();
    _ = try temporary.createIndex("before-index", "key", .{});
    try initial.commit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try upgrade.objectStore("before");
    const index = try store.index("before-index");
    try store.rename("after");
    try index.rename("after-index");
    try std.testing.expect(!database.schema().contains("before"));
    try std.testing.expect(database.schema().contains("after"));
    try std.testing.expectEqual(store, try upgrade.objectStore("after"));
    try std.testing.expectEqual(index, try store.index("after-index"));
    try upgrade.abort();
    try std.testing.expect(database.schema().contains("before"));
    try std.testing.expect(!database.schema().contains("after"));
    try std.testing.expectEqualStrings("before", store.name);
    try std.testing.expectEqualStrings("before-index", index.name);
    const names = try store.indexNames();
    defer allocator.free(names);
    try std.testing.expectEqualStrings("before-index", names[0]);
}

test "IndexedDB renames preserve handles and abort restores original names" {
    try renameAndAbort(std.testing.allocator);
}

test "IndexedDB rename and rollback unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, renameAndAbort, .{});
}
