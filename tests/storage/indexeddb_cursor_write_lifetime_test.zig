const std = @import("std");
const idb = @import("storage").indexeddb;

fn capturedWrite(allocator: std.mem.Allocator, from_index: bool, deleting: bool) !void {
    var database = idb.IDBDatabase.init(allocator, "captured-cursor-write", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    var owns_transaction = true;
    defer if (owns_transaction) transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    var owns_store = true;
    defer if (owns_store) store.deinit();
    const seeded = try store.put("before", idb.IDBKey.string("primary"));
    seeded.deinit();
    allocator.destroy(seeded);
    var index = idb.IDBIndex.init(allocator, "by-key", &store);
    var owns_index = true;
    defer if (owns_index) index.deinit();
    if (from_index) try index.addEntry(idb.IDBKey.string("secondary"), idb.IDBKey.string("primary"));
    var cursor = if (from_index)
        try idb.IDBCursor.initForIndex(allocator, &index, null, .next)
    else
        try idb.IDBCursor.init(allocator, &store, null, .next);
    var owns_cursor = true;
    defer if (owns_cursor) cursor.deinit();

    var source = try cursor.captureWriteSource(allocator);
    defer source.deinit();
    cursor.deinit();
    owns_cursor = false;
    index.deinit();
    owns_index = false;
    store.deinit();
    owns_store = false;
    transaction.deinit();
    owns_transaction = false;

    // update step 10 / delete step 7 capture the effective store and key.
    // The accepted operation must not read a destroyed cursor or index, and
    // its native owners must survive release of all original ownership.
    try std.testing.expectEqualStrings("primary", source.key.value.string);
    const request = if (deleting)
        try source.store.delete(idb.IDBKeyRange.only(source.key))
    else
        try source.store.put("after", source.key);
    defer allocator.destroy(request);
    defer request.deinit();
    if (deleting) {
        try std.testing.expectEqual(@as(usize, 0), source.store.recordsList().items.len);
    } else {
        try std.testing.expectEqualStrings("after", source.store.recordsList().items[0].value);
    }
}

test "IndexedDB accepted object store cursor update owns its native source" {
    try capturedWrite(std.testing.allocator, false, false);
}

test "IndexedDB accepted object store cursor delete owns its native source" {
    try capturedWrite(std.testing.allocator, false, true);
}

test "IndexedDB accepted index cursor update captures the effective store key" {
    try capturedWrite(std.testing.allocator, true, false);
}

test "IndexedDB accepted index cursor delete captures the effective store key" {
    try capturedWrite(std.testing.allocator, true, true);
}

test "IndexedDB cursor write capture releases every partial allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, capturedWrite, .{ true, false });
}
