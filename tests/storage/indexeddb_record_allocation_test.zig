const std = @import("std");
const idb = @import("storage").indexeddb;

fn writeRecord(allocator: std.mem.Allocator) !void {
    var database = idb.IDBDatabase.init(allocator, "record-allocation", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    const first = try store.put("first", idb.IDBKey.string("key"));
    defer allocator.destroy(first);
    const replacement = try store.put("replacement", idb.IDBKey.string("key"));
    defer allocator.destroy(replacement);
    try std.testing.expectEqualStrings("key", replacement.result.?.key.value.string);
    const duplicate = store.add("duplicate", idb.IDBKey.string("key")) catch |err| {
        // The allocation walker may fail cloning the duplicate's input key.
        if (err == error.OutOfMemory) return err;
        try std.testing.expectEqual(error.ConstraintError, err);
        return;
    };
    allocator.destroy(duplicate);
    return error.TestUnexpectedResult;
}

test "IndexedDB record mutation and request allocation have separate ownership" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, writeRecord, .{});
}
