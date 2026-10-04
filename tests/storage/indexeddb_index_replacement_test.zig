const std = @import("std");
const idb = @import("storage").indexeddb;

test "IndexedDB replacement ignores only the same primary key for uniqueness" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "replace-unique", 1);
    defer database.deinit();
    var transaction = idb.IDBTransaction.init(allocator, &database, &.{}, .readwrite);
    defer transaction.deinit();
    var store = idb.IDBObjectStore.init(allocator, "records", &transaction);
    defer store.deinit();
    var index = idb.IDBIndex.init(allocator, "unique", &store);
    defer index.deinit();
    index.unique = true;
    try index.addEntry(idb.IDBKey.string("name"), idb.IDBKey.number(1));
    var same = try index.prepareReplacementEntries(&.{idb.IDBKey.string("name")}, idb.IDBKey.number(1));
    defer same.deinit();
    try std.testing.expectError(error.ConstraintError, index.prepareReplacementEntries(&.{idb.IDBKey.string("name")}, idb.IDBKey.number(2)));
    try std.testing.expectEqual(@as(usize, 1), index.entriesList().items.len);
}
