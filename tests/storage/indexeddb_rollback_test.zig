const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB abort restores upgrade schema and connection version" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");
    const request = try factory.openPending("rollback", 1);
    defer allocator.destroy(request);
    const database = request.base.result.?.database;
    defer allocator.destroy(database);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const store = try database.createObjectStore("temporary", .{});
    defer allocator.destroy(store);
    defer store.deinit();
    try upgrade.abort();
    database.version_change_transaction = null;
    const names = try database.objectStoreNames();
    defer allocator.free(names);
    try std.testing.expectEqual(@as(usize, 0), names.len);
    try std.testing.expectEqual(@as(u64, 0), database.version);
}

test "IndexedDB abort restores records and generated key number" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-records", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const created = try database.createObjectStore("records", .{ .auto_increment = true });
    defer allocator.destroy(created);
    defer created.deinit();
    const initial = try created.put("committed", null);
    defer allocator.destroy(initial);
    try upgrade.commit();
    database.version_change_transaction = null;
    const write = try database.transaction(&.{"records"}, .readwrite, .{});
    defer allocator.destroy(write);
    defer write.deinit();
    const store = try write.objectStore("records");
    const changed = try store.put("aborted", idb.IDBKey.number(1));
    defer allocator.destroy(changed);
    const generated = try store.put("discarded", null);
    defer allocator.destroy(generated);
    try write.abort();
    const read = try database.transaction(&.{"records"}, .readonly, .{});
    defer allocator.destroy(read);
    defer read.deinit();
    const restored = try read.objectStore("records");
    const get = try restored.get(idb.IDBKeyRange.only(idb.IDBKey.number(1)));
    defer allocator.destroy(get);
    try std.testing.expectEqualStrings("committed", get.result.?.value);
    try std.testing.expectEqual(@as(u64, 2), restored.getCurrentKeyGeneratorValue());
}

fn rollbackWithAllocationFailures(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "rollback-allocation", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    const created = try database.createObjectStore("records", .{ .key_path = "id" });
    defer allocator.destroy(created);
    defer created.deinit();
    const initial = try created.put("before", idb.IDBKey.string("key"));
    defer allocator.destroy(initial);
    try upgrade.commit();
    database.version_change_transaction = null;
    const write = try database.transaction(&.{"records"}, .readwrite, .{});
    defer allocator.destroy(write);
    defer write.deinit();
    const store = try write.objectStore("records");
    const changed = try store.put("after", idb.IDBKey.string("key"));
    defer allocator.destroy(changed);
    try write.abort();
    const restored = database.schema().get("records").?.record_data.records.items[0].value;
    try std.testing.expectEqualStrings("before", restored);
}

test "IndexedDB rollback snapshot unwinds every partial allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, rollbackWithAllocationFailures, .{});
}

test "IndexedDB abort preserves a disjoint transaction's committed records" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-disjoint", 1);
    defer database.deinit();
    var upgrade = idb.IDBTransaction.init(allocator, &database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    for ([_][]const u8{ "a", "b" }) |name| {
        const store = try database.createObjectStore(name, .{});
        defer allocator.destroy(store);
        defer store.deinit();
        const request = try store.put("initial", idb.IDBKey.number(1));
        defer allocator.destroy(request);
    }
    try upgrade.commit();
    database.version_change_transaction = null;
    const first = try database.transaction(&.{"a"}, .readwrite, .{});
    defer allocator.destroy(first);
    defer first.deinit();
    const a = try first.objectStore("a");
    const aborted = try a.put("aborted", idb.IDBKey.number(1));
    defer allocator.destroy(aborted);
    const second = try database.transaction(&.{"b"}, .readwrite, .{});
    defer allocator.destroy(second);
    defer second.deinit();
    const b = try second.objectStore("b");
    const committed = try b.put("committed", idb.IDBKey.number(1));
    defer allocator.destroy(committed);
    try second.commit();
    try first.abort();
    try std.testing.expectEqualStrings("initial", database.schema().get("a").?.record_data.records.items[0].value);
    try std.testing.expectEqualStrings("committed", database.schema().get("b").?.record_data.records.items[0].value);
}
