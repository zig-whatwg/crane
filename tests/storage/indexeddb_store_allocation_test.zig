const std = @import("std");
const idb = @import("storage").indexeddb;

fn createStore(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "allocation-store", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer transaction.deinit();
    database.version_change_transaction = &transaction;
    const store = try database.createObjectStore("records", .{ .key_path = "id" });
    defer allocator.destroy(store);
    defer store.deinit();
}

test "IndexedDB createObjectStore owns metadata at every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, createStore, .{});
}
