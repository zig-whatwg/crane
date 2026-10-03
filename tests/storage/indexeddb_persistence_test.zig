const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB records and schema survive transaction handles and reopened connections" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");
    const first = try factory.open("persist", 1);
    defer allocator.destroy(first);
    const db = first.base.result.?.database;
    defer allocator.destroy(db);
    defer db.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, db, &.{}, .versionchange);
    defer upgrade.deinit();
    db.version_change_transaction = &upgrade;
    const store = try db.createObjectStore("records", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    const put = try store.put("serialized record", idb.IDBKey.number(7));
    defer allocator.destroy(put);
    try upgrade.commit();
    db.version_change_transaction = null;
    db.close();
    const second = try factory.open("persist", null);
    defer allocator.destroy(second);
    const reopened = second.base.result.?.database;
    defer allocator.destroy(reopened);
    defer reopened.deinit();
    const transaction = try reopened.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(transaction);
    defer transaction.deinit();
    const handle = try transaction.objectStore("records");
    const get = try handle.get(idb.IDBKeyRange.only(idb.IDBKey.number(7)));
    defer allocator.destroy(get);
    try std.testing.expectEqualStrings("serialized record", get.result.?.value);
}

test "IndexedDB an upgraded version becomes visible to later opens" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");
    const versions = [_]u64{ 1, 2, 2 };
    for (versions, 0..) |version, index| {
        const request = try factory.open("versions", if (index == 2) null else version);
        defer allocator.destroy(request);
        const database = request.base.result.?.database;
        defer allocator.destroy(database);
        defer database.deinit();
        try std.testing.expectEqual(version, database.version);
        database.close();
    }
}
