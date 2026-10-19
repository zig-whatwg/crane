//! IndexedDB on two threads at once, as a page and a dedicated worker of one
//! Browser run now that every dedicated worker has a thread of its own
//! (docs/instances.md, "Decisions"; workers 1B-ii).
//!
//! IndexedDB storage is the Browser's: one IDBServer per Browser (a
//! BrowserScope supplement; src/storage/indexeddb/server.zig), keyed by
//! storage key, so a page and its workers SHARE a database of one name - its
//! versions, stores and records - and two Browsers share nothing. (This test
//! used to pin the opposite: each IDBFactory owned a backend of its own, and
//! a page's and a worker's databases of one name were two databases.)
//!
//! Each side here is an engine-free agent on a thread of its own, with a
//! fake task sink (idb_fake_agent.zig), and drives the server the way the
//! IDBFactory impl does: enqueue an open request, wait to reach the head of
//! the connection queue (ED 2.8.2), open a connection, run an upgrade
//! transaction that adds one store of its own, commit, close, and leave the
//! queue - which tells the other side's request, on the other thread, to go
//! on. In Debug, std's hash maps panic at the first concurrent mutation of a
//! shared one: the lock and the queue are what keep that from happening.
//!
//! tests/storage is one executable: nothing here assumes it runs first.

const std = @import("std");
const idb = @import("storage").indexeddb;
const server_mod = idb.server;
const FakeAgent = @import("idb_fake_agent.zig").FakeAgent;
const Signal = @import("idb_fake_agent.zig").Signal;

const origin = "https://shared.example";
const database_name = "shared";
const round_count: u64 = 60;
const records_per_store = 3;

const Side = struct {
    id: u8,
    server: *idb.IDBServer,
    allocator: std.mem.Allocator,
    start: *std.atomic.Value(bool),
    /// Whether the other side shares this side's server.
    shared: bool,
    failed: ?anyerror = null,

    fn run(self: *Side) void {
        // Both threads begin together, so their rounds overlap.
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        self.runRounds() catch |err| {
            self.failed = err;
        };
    }

    fn runRounds(self: *Side) !void {
        var agent = FakeAgent.init(self.allocator);
        defer agent.deinit();
        var round: u64 = 0;
        while (round < round_count) : (round += 1) try self.upgrade(&agent, round);
    }

    /// Wait for the head of the queue, then open the database one version
    /// higher than it is now, and add one store of this side's.
    fn upgrade(self: *Side, agent: *FakeAgent, round: u64) !void {
        const allocator = self.allocator;
        const key = idb.server.firstPartyKey(origin);
        const database = try self.server.uniqueDatabase(key, database_name);
        defer self.server.release(database);
        var signal: Signal = .{};
        const queued = try self.server.enqueue(database, agent.endpoint(), signal.client());
        if (!queued.head) agent.runUntil(&signal.flag);

        const start = try self.server.start(database, queued.id, null, false, allocator);
        const proceed = start.proceed;
        defer allocator.free(proceed.local);
        const target = proceed.old_version + 1;
        // Isolated, this side's rounds are the only ones; shared, the other
        // side's rounds raise the version too.
        if (!self.shared) try std.testing.expectEqual(round + 1, target);
        try std.testing.expect(self.server.awaitCloses(database, queued.id));

        const opened = try self.server.openConnection(database, target, true, allocator, agent.endpoint());
        const connection = opened.connection;
        try self.addStore(connection, round, target, database);
        // Closed - and gone from the set - before the queue moves on.
        connection.close();
        connection.releaseHeapOwnership();
        self.server.dequeue(database, queued.id);
    }

    fn addStore(self: *Side, connection: *idb.IDBDatabase, round: u64, target: u64, database: *server_mod.UniqueIDBDatabase) !void {
        const allocator = self.allocator;
        var transaction = idb.IDBTransaction.init(allocator, connection, &.{}, .versionchange);
        defer transaction.deinit();
        try transaction.register();
        connection.version_change_transaction = &transaction;
        defer connection.version_change_transaction = null;
        var name_buffer: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buffer, "t{d}-r{d}", .{ self.id, round });
        const store = try connection.createObjectStore(name, .{});
        defer allocator.destroy(store);
        defer store.deinit();
        for (0..records_per_store) |i| {
            const put = try store.put("value", idb.IDBKey.number(@floatFromInt(i)));
            put.deinit();
            allocator.destroy(put);
        }
        try transaction.commit();
        try std.testing.expectEqual(target, self.server.currentVersion(database));

        // Every store this side and - shared - the other side added so far.
        const names = try connection.objectStoreNames();
        defer allocator.free(names);
        var mine: u64 = 0;
        var prefix_buffer: [8]u8 = undefined;
        const prefix = try std.fmt.bufPrint(&prefix_buffer, "t{d}-", .{self.id});
        for (names) |store_name| {
            if (std.mem.startsWith(u8, store_name, prefix)) mine += 1;
        }
        try std.testing.expectEqual(round + 1, mine);
        if (self.shared) try std.testing.expectEqual(target, names.len) else try std.testing.expectEqual(round + 1, names.len);
    }
};

fn runSides(sides: []Side) !void {
    var threads: [2]std.Thread = undefined;
    for (sides, &threads) |*side, *thread| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    sides[0].start.store(true, .release);
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failed) |err| return err;
}

test "two threads of one Browser share its IndexedDB databases under one storage key" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    var start = std.atomic.Value(bool).init(false);
    var sides = [_]Side{
        .{ .id = 0, .server = &server, .allocator = allocator, .start = &start, .shared = true },
        .{ .id = 1, .server = &server, .allocator = allocator, .start = &start, .shared = true },
    };
    try runSides(&sides);

    // One database, upgraded by both sides' rounds, with both sides' stores.
    var factory = idb.IDBFactory.initShared(allocator, &server);
    defer factory.deinit();
    factory.setStorageKey(origin);
    const list = try factory.databases();
    defer server_mod.freeInfos(allocator, list);
    try std.testing.expectEqual(@as(usize, 1), list.len);
    try std.testing.expectEqualStrings(database_name, list[0].name);
    try std.testing.expectEqual(2 * round_count, list[0].version);
}

test "two Browsers on two threads opening one name each see only their own database" {
    // A Browser's own leak-checking allocator each: the shared test
    // allocator's lock would make the two threads take turns (lesson
    // testing-a-shared-test-allocator-makes-two-browsers-take-turns).
    var first_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(first_allocator.deinit() == .ok) catch @panic("the first Browser leaked");
    var second_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(second_allocator.deinit() == .ok) catch @panic("the second Browser leaked");
    var first = idb.IDBServer.init(first_allocator.allocator());
    defer first.deinit();
    var second = idb.IDBServer.init(second_allocator.allocator());
    defer second.deinit();
    var start = std.atomic.Value(bool).init(false);
    var sides = [_]Side{
        .{ .id = 0, .server = &first, .allocator = first_allocator.allocator(), .start = &start, .shared = false },
        .{ .id = 1, .server = &second, .allocator = second_allocator.allocator(), .start = &start, .shared = false },
    };
    try runSides(&sides);
    for ([_]*idb.IDBServer{ &first, &second }) |server| {
        const database = try server.uniqueDatabase(idb.server.firstPartyKey(origin), database_name);
        defer server.release(database);
        try std.testing.expectEqual(round_count, server.currentVersion(database));
    }
}
