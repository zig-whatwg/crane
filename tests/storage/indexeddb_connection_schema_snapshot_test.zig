const std = @import("std");
const idb = @import("storage").indexeddb;

fn connectionNames(allocator: std.mem.Allocator) !void {
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://schema.example");
    const first_request = try factory.open("names", 1);
    defer allocator.destroy(first_request);
    defer first_request.deinit();
    const first = first_request.base.result.?.database;
    defer allocator.destroy(first);
    defer first.deinit();
    var initial = idb.IDBTransaction.init(allocator, first, &.{}, .versionchange);
    defer initial.deinit();
    first.version_change_transaction = &initial;
    const original = try first.createObjectStore("original", .{});
    defer allocator.destroy(original);
    defer original.deinit();
    try initial.commit();
    first.version_change_transaction = null;
    first.close();

    const second_request = try factory.open("names", 2);
    defer allocator.destroy(second_request);
    defer second_request.deinit();
    const second = second_request.base.result.?.database;
    defer allocator.destroy(second);
    defer second.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, second, &.{}, .versionchange);
    defer upgrade.deinit();
    second.version_change_transaction = &upgrade;
    const store = try upgrade.objectStore("original");
    try store.rename("later");
    const before = try first.objectStoreNames();
    defer allocator.free(before);
    const after = try second.objectStoreNames();
    defer allocator.free(after);
    try std.testing.expectEqualStrings("original", before[0]);
    try std.testing.expectEqualStrings("later", after[0]);
    try upgrade.abort();
    const restored = try second.objectStoreNames();
    defer allocator.free(restored);
    try std.testing.expectEqualStrings("original", restored[0]);
}

test "IndexedDB closed connection names do not change with another upgrade" {
    try connectionNames(std.testing.allocator);
}

test "IndexedDB connection schema snapshots unwind allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, connectionNames, .{});
}
