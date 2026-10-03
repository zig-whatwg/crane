const std = @import("std");
const idb = @import("storage").indexeddb;

fn compoundMetadata(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "compound-metadata", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    var first_name = [_]u8{ 'f', 'i', 'r', 's', 't' };
    const paths = [_][]const u8{ &first_name, "last" };
    const store = try database.createObjectStore("records", .{ .compound_key_path = &paths });
    defer allocator.destroy(store);
    defer store.deinit();
    const index = try store.createIndexWithKeyPath("by-name", .{ .array = &paths }, .{});
    first_name[0] = 'x';
    try std.testing.expectEqualStrings("first", store.compound_key_path.?[0]);
    try std.testing.expectEqualStrings("first", index.compound_key_path.?[0]);
    try upgrade.commit();
    database.version_change_transaction = null;
    const read = try database.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(read);
    defer read.deinit();
    const reopened = try read.objectStore("records");
    const reopened_index = try reopened.index("by-name");
    try std.testing.expect(reopened.key_path == null);
    try std.testing.expect(reopened_index.key_path == null);
    try std.testing.expectEqual(@as(usize, 2), reopened.compound_key_path.?.len);
    try std.testing.expectEqualStrings("first", reopened.compound_key_path.?[0]);
    try std.testing.expectEqualStrings("last", reopened_index.compound_key_path.?[1]);
}

test "IndexedDB compound store and index definitions own all path strings" {
    try compoundMetadata(std.testing.allocator);
}

test "IndexedDB compound definitions unwind every partial allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, compoundMetadata, .{});
}
