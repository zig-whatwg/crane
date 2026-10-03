const std = @import("std");
const idb = @import("storage").indexeddb;

fn readRecord(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "request-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("value", idb.IDBKey.number(1));
    allocator.destroy(write);
    // Existing requests are borrowed; discard their list capacity to exercise
    // the read's allocation AFTER its request has been allocated.
    transaction.requests.deinit(allocator);
    transaction.requests = .empty;
    const read = try store.get(idb.IDBKeyRange.only(idb.IDBKey.number(1)));
    defer allocator.destroy(read);
    try std.testing.expectEqualStrings("value", read.result.?.value);
}

test "IndexedDB read request unwinds failure to append to transaction" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, readRecord, .{});
}

test "IndexedDB clear allocation failure leaves records intact" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const allocator = failing.allocator();
    var database = idb.IDBDatabase.init(allocator, "clear-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const write = try store.put("value", idb.IDBKey.number(1));
    defer allocator.destroy(write);
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, store.clear());
    try std.testing.expectEqual(@as(usize, 1), store.recordsList().items.len);
    try std.testing.expectEqualStrings("value", store.recordsList().items[0].value);
}

fn readIndex(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "index-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readonly);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "index", &store);
    defer index.deinit();
    const read = try index.get(idb.IDBKeyRange.unbounded());
    defer allocator.destroy(read);
    try std.testing.expect(read.result.? == .undefined);
}

test "IndexedDB index request unwinds failure to append to transaction" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, readIndex, .{});
}
