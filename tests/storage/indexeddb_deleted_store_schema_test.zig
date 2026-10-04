const std = @import("std");
const idb = @import("storage").indexeddb;

fn deletedHandleNames(allocator: std.mem.Allocator, abort: bool) !void {
    var database = idb.IDBDatabase.init(allocator, "deleted-schema", 1);
    defer database.deinit();
    var initial = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer initial.deinit();
    database.version_change_transaction = &initial;
    const temporary = try database.createObjectStore("records", .{});
    defer allocator.destroy(temporary);
    defer temporary.deinit();
    _ = try temporary.createIndex("by-key", "key", .{});
    try initial.commit();
    database.version_change_transaction = null;

    const read = try database.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(read);
    defer read.deinit();
    const previous = try read.objectStore("records");
    try read.commit();

    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const removed = try upgrade.objectStore("records");
    try database.deleteObjectStore("records");
    const during = try removed.indexNames();
    defer allocator.free(during);
    try std.testing.expectEqual(@as(usize, 0), during.len);
    if (abort) try upgrade.abort() else try upgrade.commit();

    // ED 4.4 deleteObjectStore step 6 changes only this transaction's handle.
    // Commit preserves that empty set; ED 5.8.5.2 restores it only on abort.
    const after = try removed.indexNames();
    defer allocator.free(after);
    try std.testing.expectEqual(@as(usize, if (abort) 1 else 0), after.len);
    if (abort) try std.testing.expectEqualStrings("by-key", after[0]);
    const old = try previous.indexNames();
    defer allocator.free(old);
    try std.testing.expectEqual(@as(usize, 1), old.len);
    try std.testing.expectEqualStrings("by-key", old[0]);
}

test "IndexedDB deleting a store keeps its handle index set empty after commit" {
    try deletedHandleNames(std.testing.allocator, false);
}

test "IndexedDB deleting a store restores its handle index set only on abort" {
    try deletedHandleNames(std.testing.allocator, true);
}

test "IndexedDB deleted handle schema snapshots unwind allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, deletedHandleNames, .{false});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, deletedHandleNames, .{true});
}
