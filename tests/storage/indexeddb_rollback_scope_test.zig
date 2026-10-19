//! A readwrite transaction's rollback snapshot (IndexedDB 5.5 step 2)
//! copies only the stores in its scope. Another store's records may belong
//! to another transaction while this one runs - ED 2.7.2 lets transactions
//! with disjoint scopes run at once - and with IndexedDB storage shared per
//! Browser, that other transaction may be on another thread: copying its
//! store would read records it is writing, and restoring them would undo
//! its writes.
//!
//! tests/storage is one executable: nothing here assumes it runs first.

const std = @import("std");
const idb = @import("storage").indexeddb;

fn addStores(database: *idb.IDBDatabase, names: []const []const u8) !void {
    var upgrade = idb.IDBTransaction.init(std.testing.allocator, database, &.{}, .versionchange);
    defer upgrade.deinit();
    database.version_change_transaction = &upgrade;
    defer database.version_change_transaction = null;
    for (names) |name| {
        const store = try database.createObjectStore(name, .{});
        store.deinit();
        std.testing.allocator.destroy(store);
    }
    try upgrade.commit();
}

fn put(store: *idb.IDBObjectStore, key: f64) !void {
    const request = try store.put("value", idb.IDBKey.number(key));
    request.deinit();
    std.testing.allocator.destroy(request);
}

test "IndexedDB a readwrite transaction's rollback snapshot holds only the stores in its scope" {
    const allocator = std.testing.allocator;
    var database = idb.IDBDatabase.init(allocator, "rollback-scope", 1);
    defer database.deinit();
    try addStores(&database, &.{ "a", "b" });
    const transaction = try database.transaction(&.{"a"}, .readwrite, .{});
    defer {
        transaction.deinit();
        allocator.destroy(transaction);
    }
    try put(try transaction.objectStore("a"), 1);
    const snapshot = transaction.rollback_schema orelse return error.TestExpectedSnapshot;
    try std.testing.expectEqual(@as(u32, 1), snapshot.count());
    try std.testing.expect(snapshot.contains("a"));
    try std.testing.expect(!snapshot.contains("b"));
    try transaction.abort();
}

const rounds = 200;
const writes_per_round = 8;

/// One side: `rounds` readwrite transactions over its own store, each
/// committed (the writer) or aborted (the aborter), on its own connection.
const Side = struct {
    connection: *idb.IDBDatabase,
    store_name: []const u8,
    abort: bool,
    start: *std.atomic.Value(bool),
    failed: ?anyerror = null,

    fn run(self: *Side) void {
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        self.steps() catch |err| {
            self.failed = err;
        };
    }

    fn steps(self: *Side) !void {
        const allocator = std.testing.allocator;
        for (0..rounds) |round| {
            const transaction = try self.connection.transaction(&.{self.store_name}, .readwrite, .{});
            defer {
                transaction.deinit();
                allocator.destroy(transaction);
            }
            try std.testing.expect(transaction.canStart());
            try transaction.beginRequestExecution();
            const store = try transaction.objectStore(self.store_name);
            for (0..writes_per_round) |i| try put(store, @floatFromInt(round * writes_per_round + i));
            transaction.endRequestExecution();
            if (self.abort) try transaction.abort() else try transaction.commit();
        }
    }
};

test "IndexedDB a readwrite abort on one thread leaves another thread's store and its writes alone" {
    const allocator = std.testing.allocator;
    var factory = idb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://rollback-scope.example");
    const first = try factory.open("rollback-threads", 1);
    defer allocator.destroy(first);
    defer first.deinit();
    const writer_connection = first.base.result.?.database;
    defer allocator.destroy(writer_connection);
    defer writer_connection.deinit();
    try addStores(writer_connection, &.{ "written", "aborted" });
    const second = try factory.open("rollback-threads", 1);
    defer allocator.destroy(second);
    defer second.deinit();
    const aborter_connection = second.base.result.?.database;
    defer allocator.destroy(aborter_connection);
    defer aborter_connection.deinit();

    var start = std.atomic.Value(bool).init(false);
    var sides = [_]Side{
        .{ .connection = writer_connection, .store_name = "written", .abort = false, .start = &start },
        .{ .connection = aborter_connection, .store_name = "aborted", .abort = true, .start = &start },
    };
    var threads: [2]std.Thread = undefined;
    for (&sides, &threads) |*side, *thread| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    start.store(true, .release);
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failed) |err| return err;

    // Every committed write is there; every aborted one is gone.
    const check = try writer_connection.transaction(&.{ "written", "aborted" }, .readonly, .{});
    defer {
        check.deinit();
        allocator.destroy(check);
    }
    try check.beginRequestExecution();
    defer check.endRequestExecution();
    inline for (.{ .{ "written", rounds * writes_per_round }, .{ "aborted", 0 } }) |expected| {
        const counted = try (try check.objectStore(expected[0])).count(null);
        defer {
            counted.deinit();
            allocator.destroy(counted);
        }
        try std.testing.expectEqual(@as(u64, expected[1]), counted.result.?.count);
    }
    try check.commit();
}
