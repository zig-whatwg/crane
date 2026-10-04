const std = @import("std");
const idb = @import("storage").indexeddb;

fn abortEmptyUpgrade(allocator: std.mem.Allocator, existing: bool) !void {
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://empty-upgrade.example");
    if (existing) {
        const request = try factory.open("database", 1);
        defer allocator.destroy(request);
        defer request.deinit();
        const connection = request.base.result.?.database;
        defer allocator.destroy(connection);
        defer connection.deinit();
        connection.close();
    }
    const request = try factory.openPending("database", 2);
    defer allocator.destroy(request);
    defer request.deinit();
    const connection = request.base.result.?.database;
    defer allocator.destroy(connection);
    defer connection.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, connection, &.{}, .versionchange);
    defer upgrade.deinit();
    connection.version_change_transaction = &upgrade;
    // ED 5.8.3 also reverts version when the upgrade issued no requests and
    // changed no schema, so no lazy record/schema snapshot was needed.
    try upgrade.abort();
    try std.testing.expectEqual(@as(u64, if (existing) 1 else 0), connection.version);
}

test "IndexedDB an empty aborted upgrade restores the connection version" {
    try abortEmptyUpgrade(std.testing.allocator, false);
    try abortEmptyUpgrade(std.testing.allocator, true);
}

test "IndexedDB empty upgrade rollback unwinds allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, abortEmptyUpgrade, .{false});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, abortEmptyUpgrade, .{true});
}

test "IndexedDB databases excludes uncommitted version zero databases" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://pending-upgrade.example");
    const request = try factory.openPending("uncommitted", 4);
    defer allocator.destroy(request);
    defer request.deinit();
    const connection = request.base.result.?.database;
    defer allocator.destroy(connection);
    defer connection.deinit();
    const databases = try factory.databases();
    defer allocator.free(databases);
    try std.testing.expectEqual(@as(usize, 0), databases.len);
}
