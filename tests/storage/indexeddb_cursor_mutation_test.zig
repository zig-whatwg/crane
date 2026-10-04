const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB cursor continuation follows its key after an earlier insertion" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "cursor-mutation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const first = try store.put("one", idb.IDBKey.number(1));
    defer allocator.destroy(first);
    const second = try store.put("three", idb.IDBKey.number(3));
    defer allocator.destroy(second);
    const request = try store.openCursor(null, .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    try std.testing.expectEqual(@as(f64, 1), cursor.key.?.value.number);
    const inserted = try store.put("zero", idb.IDBKey.number(0));
    defer allocator.destroy(inserted);
    try cursor.@"continue"(null);
    try std.testing.expectEqual(@as(f64, 3), cursor.key.?.value.number);
}

test "IndexedDB value cursor over an index exposes the referenced record" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "index-cursor-value", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("stored-value", idb.IDBKey.number(1));
    defer allocator.destroy(write);
    var index = idb.IDBIndex.init(allocator, "by-key", &store);
    defer index.deinit();
    try index.addEntry(idb.IDBKey.string("entry"), idb.IDBKey.number(1));
    const request = try index.openCursor(null, .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    try std.testing.expect(cursor.value != null);
    try std.testing.expectEqualStrings("stored-value", cursor.value.?);
}

test "IndexedDB cursor key and value snapshots survive record removal" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "cursor-snapshot", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("stored-value", idb.IDBKey.string("owned-key"));
    defer allocator.destroy(write);
    const request = try store.openCursor(null, .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    const clear = try store.clear();
    defer allocator.destroy(clear);
    try std.testing.expectEqualStrings("owned-key", cursor.key.?.value.string);
    try std.testing.expectEqualStrings("stored-value", cursor.value.?);
}

fn cursorAllocationWalk(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "cursor-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("stored-value", idb.IDBKey.string("key"));
    defer allocator.destroy(write);
    const request = try store.openCursor(idb.IDBKeyRange.only(idb.IDBKey.string("key")), .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    try std.testing.expectEqualStrings("key", cursor.key.?.value.string);
    try cursor.@"continue"(null);
    try std.testing.expect(!cursor.got_value);
}

test "IndexedDB cursor snapshot allocations unwind every partial copy" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cursorAllocationWalk, .{});
}

test "IndexedDB cursor update recreates a removed current record" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "cursor-recreate", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("before", idb.IDBKey.number(1));
    defer allocator.destroy(write);
    const request = try store.openCursor(null, .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    const clear = try store.clear();
    defer allocator.destroy(clear);
    const updated = try cursor.update("after");
    defer allocator.destroy(updated);
    try std.testing.expectEqual(@as(usize, 1), store.recordsList().items.len);
    try std.testing.expectEqualStrings("after", store.recordsList().items[0].value);
}

fn cursorDeleteWalk(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "cursor-delete-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("stored-value", idb.IDBKey.string("key"));
    defer allocator.destroy(write);
    const request = try store.openCursor(null, .next);
    defer allocator.destroy(request);
    const cursor = request.result.?.cursor;
    defer allocator.destroy(cursor);
    defer cursor.deinit();
    transaction.requests.deinit(allocator);
    transaction.requests = .empty;
    const deleted = cursor.delete() catch |err| {
        try std.testing.expectEqual(@as(usize, 1), store.recordsList().items.len);
        return err;
    };
    defer allocator.destroy(deleted);
    try std.testing.expectEqual(@as(usize, 0), store.recordsList().items.len);
}

test "IndexedDB cursor delete allocation failure leaves records intact" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cursorDeleteWalk, .{});
}
