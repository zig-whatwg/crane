const std = @import("std");
const idb = @import("storage").indexeddb;

fn addStores(database: *idb.IDBDatabase) !void {
    var upgrade = idb.IDBTransaction.init(std.testing.allocator, database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    defer database.version_change_transaction = null;
    for ([_][]const u8{ "a", "b" }) |name| {
        const store = try database.createObjectStore(name, .{});
        store.deinit();
        std.testing.allocator.destroy(store);
    }
    try upgrade.commit();
}

test "IndexedDB overlapping transactions start in creation order" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "scheduling", 1);
    defer database.deinit();
    try addStores(&database);
    const read1 = try database.transaction(&.{"a"}, .readonly, .{});
    defer allocator.destroy(read1);
    defer read1.deinit();
    const read2 = try database.transaction(&.{"a"}, .readonly, .{});
    defer allocator.destroy(read2);
    defer read2.deinit();
    const write = try database.transaction(&.{"a"}, .readwrite, .{});
    defer allocator.destroy(write);
    defer write.deinit();
    const later_read = try database.transaction(&.{"a"}, .readonly, .{});
    defer allocator.destroy(later_read);
    defer later_read.deinit();
    const disjoint = try database.transaction(&.{"b"}, .readwrite, .{});
    defer allocator.destroy(disjoint);
    defer disjoint.deinit();
    try std.testing.expect(read1.canStart());
    try std.testing.expect(read2.canStart());
    try std.testing.expect(!write.canStart());
    try std.testing.expect(!later_read.canStart());
    try std.testing.expect(disjoint.canStart());
    try read1.commit();
    try std.testing.expect(!write.canStart());
    try read2.commit();
    try std.testing.expect(write.canStart());
    try std.testing.expect(!later_read.canStart());
    try write.commit();
    try std.testing.expect(later_read.canStart());
}

test "IndexedDB transaction scheduling spans connections to one database" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");
    const first = try factory.open("shared-scheduling", 1);
    defer allocator.destroy(first);
    const database = first.base.result.?.database;
    defer allocator.destroy(database);
    defer database.deinit();
    try addStores(database);
    const second = try factory.open("shared-scheduling", 1);
    defer allocator.destroy(second);
    const other = second.base.result.?.database;
    defer allocator.destroy(other);
    defer other.deinit();
    const write = try database.transaction(&.{"a"}, .readwrite, .{});
    defer allocator.destroy(write);
    defer write.deinit();
    const read = try other.transaction(&.{"a"}, .readonly, .{});
    defer allocator.destroy(read);
    defer read.deinit();
    try std.testing.expect(!read.canStart());
    try write.commit();
    try std.testing.expect(read.canStart());
}

test "IndexedDB a waiting handle sees the preceding transaction rollback" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-scheduling", 1);
    defer database.deinit();
    try addStores(&database);
    const first = try database.transaction(&.{"a"}, .readwrite, .{});
    defer allocator.destroy(first);
    defer first.deinit();
    const first_store = try first.objectStore("a");
    const write = try first_store.put("uncommitted", idb.IDBKey.number(1));
    write.deinit();
    allocator.destroy(write);

    const waiting = try database.transaction(&.{"a"}, .readonly, .{});
    defer allocator.destroy(waiting);
    defer waiting.deinit();
    const waiting_store = try waiting.objectStore("a");
    try std.testing.expect(!waiting.canStart());
    try first.abort();
    try waiting.beginRequestExecution();
    defer waiting.endRequestExecution();
    const read = try waiting_store.get(idb.IDBKeyRange.only(idb.IDBKey.number(1)));
    defer allocator.destroy(read);
    defer read.deinit();
    try std.testing.expect(read.result.? == .undefined);
}
