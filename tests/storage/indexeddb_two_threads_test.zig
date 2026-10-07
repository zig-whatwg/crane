//! IndexedDB on two threads at once, as a page and a dedicated worker run
//! now that every dedicated worker has a thread of its own
//! (docs/instances.md, "Decisions"; workers 1B-ii).
//!
//! Each IDBFactory platform object owns its own backend factory
//! (src/webidl/impls/IDBFactory.zig `init` makes one), and the backend keeps
//! every database in that factory's own map: two factories share nothing,
//! so a page's and a worker's IndexedDB need no lock between them (the
//! integrator's ruling for workers 1B-ii item 7: no boundary lock). This
//! test pins that: two threads, each with its own backend factory under the
//! SAME storage key and the SAME database name, open, upgrade, create
//! stores, put, count and list concurrently - in Debug, where std's hash
//! maps panic at the first concurrent mutation of a shared one - and each
//! sees only its own versions, stores and records.
//!
//! THIS PINS TODAY'S PER-FACTORY ISOLATION, NOT THE FINAL MODEL. The queued
//! IndexedDB shared-storage item will make the page and the workers of one
//! storage key share a backend per Browser, as the spec's storage model has
//! it - and then the boundary lock comes with it, and this test changes
//! with it.
//!
//! tests/storage is one executable: nothing here assumes it runs first.

const std = @import("std");
const idb = @import("storage").indexeddb;

const storage_key = "https://shared.example";
const database_name = "shared";
const round_count: u64 = 150;
const records_per_store = 3;

const Side = struct {
    id: u8,
    start: *std.atomic.Value(bool),
    failed: ?anyerror = null,

    fn run(self: *Side) void {
        // Both threads begin together, so their rounds overlap.
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        self.runRounds() catch |err| {
            self.failed = err;
        };
    }

    fn runRounds(self: *Side) !void {
        const allocator = std.testing.allocator;
        var factory = idb.IDBFactory.init(allocator);
        defer factory.deinit();
        factory.setStorageKey(storage_key);

        var round: u64 = 0;
        while (round < round_count) : (round += 1) try self.upgrade(allocator, &factory, round);

        // One database, at this side's own last version.
        const list = try factory.databases();
        defer allocator.free(list);
        try std.testing.expectEqual(@as(usize, 1), list.len);
        try std.testing.expectEqualStrings(database_name, list[0].name);
        try std.testing.expectEqual(round_count, list[0].version);
    }

    /// Open the database at version `round + 1`, upgrading it from this
    /// side's own previous version, and add one store of this side's.
    fn upgrade(self: *Side, allocator: std.mem.Allocator, factory: *idb.IDBFactory, round: u64) !void {
        const request = try factory.open(database_name, round + 1);
        defer allocator.destroy(request);
        defer request.deinit();
        // The version the other thread's factory reached is not this one's.
        try std.testing.expectEqual(round, request.old_version);
        try std.testing.expectEqual(round + 1, request.new_version);
        const database = request.base.result.?.database;
        defer allocator.destroy(database);
        defer database.deinit();

        var transaction = idb.IDBTransaction.init(allocator, database, &.{}, .versionchange);
        defer transaction.deinit();
        database.version_change_transaction = &transaction;
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "t{d}-r{d}", .{ self.id, round });
        const store = try database.createObjectStore(name, .{});
        defer allocator.destroy(store);
        defer store.deinit();
        for (0..records_per_store) |i| {
            const put = try store.put("value", idb.IDBKey.number(@floatFromInt(i)));
            allocator.destroy(put);
        }
        const counted = try store.count(null);
        defer allocator.destroy(counted);
        try std.testing.expectEqual(@as(u64, records_per_store), counted.result.?.count);
        try transaction.commit();
        database.version_change_transaction = null;

        // Every store is this side's: one per round so far.
        const names = try database.objectStoreNames();
        defer allocator.free(names);
        try std.testing.expectEqual(round + 1, names.len);
        var prefix_buffer: [8]u8 = undefined;
        const prefix = try std.fmt.bufPrint(&prefix_buffer, "t{d}-", .{self.id});
        for (names) |store_name| try std.testing.expect(std.mem.startsWith(u8, store_name, prefix));
        database.close();
    }
};

test "two threads' IndexedDB factories under one storage key share nothing" {
    var start = std.atomic.Value(bool).init(false);
    var sides = [_]Side{ .{ .id = 0, .start = &start }, .{ .id = 1, .start = &start } };
    var threads: [2]std.Thread = undefined;
    for (&sides, &threads) |*side, *thread| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    start.store(true, .release);
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failed) |err| return err;
}
