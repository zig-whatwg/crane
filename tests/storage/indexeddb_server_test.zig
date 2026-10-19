//! The Browser's IndexedDB server across agents and threads
//! (src/storage/indexeddb/server.zig): versionchange delivered to another
//! thread and acknowledged before `blocked` is decided, a close there
//! letting the waiting request go on, the transaction scheduler across
//! threads, and an agent's end mid-upgrade - every agent engine-free, with a
//! fake task sink (idb_fake_agent.zig).
//!
//! tests/storage is one executable: nothing here assumes it runs first.

const std = @import("std");
const idb = @import("storage").indexeddb;
const server_mod = idb.server;
const FakeAgent = @import("idb_fake_agent.zig").FakeAgent;
const Signal = @import("idb_fake_agent.zig").Signal;

const origin = "https://server.example";

fn key() server_mod.StorageKey {
    return server_mod.firstPartyKey(origin);
}

/// Open `name` at `version` with no other connection to wait on.
fn openAlone(server: *idb.IDBServer, agent: *FakeAgent, name: []const u8, version: u64) !*idb.IDBDatabase {
    const database = try server.uniqueDatabase(key(), name);
    defer server.release(database);
    var signal: Signal = .{};
    const queued = try server.enqueue(database, agent.endpoint(), signal.client());
    try std.testing.expect(queued.head);
    const start = try server.start(database, queued.id, version, false, std.testing.allocator);
    std.testing.allocator.free(start.proceed.local);
    try std.testing.expect(server.awaitAcknowledgements(database, queued.id));
    try std.testing.expect(server.awaitCloses(database, queued.id));
    const opened = try server.openConnection(database, version, false, std.testing.allocator, agent.endpoint());
    server.dequeue(database, queued.id);
    return opened.connection;
}

/// A connection that hears versionchange on its own thread.
const Listener = struct {
    heard: std.atomic.Value(u32) = .init(0),
    old_version: u64 = 0,
    new_version: ?u64 = null,
    posted: bool = false,

    fn hook(self: *Listener) idb.IDBDatabase.VersionChangeHook {
        return .{ .context = self, .call = call };
    }
    fn call(context: *anyopaque, old_version: u64, new_version: ?u64, posted: bool) void {
        const self: *Listener = @ptrCast(@alignCast(context));
        self.old_version = old_version;
        self.new_version = new_version;
        self.posted = posted;
        _ = self.heard.fetchAdd(1, .release);
    }
};

/// The page's side of the versionchange test: a connection on its own
/// thread, which hears versionchange and closes only when told.
const Holder = struct {
    server: *idb.IDBServer,
    opened: std.atomic.Value(bool) = .init(false),
    close_now: std.atomic.Value(bool) = .init(false),
    done: std.atomic.Value(bool) = .init(false),
    listener: Listener = .{},
    failed: ?anyerror = null,

    fn run(self: *Holder) void {
        self.steps() catch |err| {
            self.failed = err;
        };
        self.done.store(true, .release);
    }

    fn steps(self: *Holder) !void {
        var agent = FakeAgent.init(std.testing.allocator);
        defer agent.deinit();
        const connection = try openAlone(self.server, &agent, "versionchange", 1);
        connection.version_change_hook = self.listener.hook();
        self.opened.store(true, .release);
        // Run this agent's tasks - the posted versionchange among them -
        // until the test says to close.
        agent.runUntil(&self.close_now);
        connection.version_change_hook = null;
        connection.close();
        connection.closePending();
        connection.releaseHeapOwnership();
    }
};

test "IndexedDB versionchange reaches another thread's connection, then blocked, and its close lets the open go on" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    var holder: Holder = .{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Holder.run, .{&holder});
    defer thread.join();
    defer holder.close_now.store(true, .release);
    while (!holder.opened.load(.acquire)) std.Thread.yield() catch {};

    var agent = FakeAgent.init(allocator);
    defer agent.deinit();
    const database = try server.uniqueDatabase(key(), "versionchange");
    defer server.release(database);
    var signal: Signal = .{};
    const queued = try server.enqueue(database, agent.endpoint(), signal.client());
    try std.testing.expect(queued.head);

    // ED 5.1 step 10.2: the other thread's connection is told by a task of
    // its own loop, not by this thread.
    const start = try server.start(database, queued.id, 2, false, allocator);
    defer allocator.free(start.proceed.local);
    try std.testing.expect(start.proceed.change);
    try std.testing.expectEqual(@as(usize, 0), start.proceed.local.len);

    // Step 10.3: wait until it has fired; its acknowledgement advances us.
    if (!server.awaitAcknowledgements(database, queued.id)) agent.runUntil(&signal.flag);
    try std.testing.expectEqual(@as(u32, 1), holder.listener.heard.load(.acquire));
    try std.testing.expectEqual(@as(u64, 1), holder.listener.old_version);
    try std.testing.expectEqual(@as(?u64, 2), holder.listener.new_version);
    try std.testing.expect(holder.listener.posted);

    // Step 10.4: the connection did not close: blocked. Step 10.5: wait.
    try std.testing.expect(server.hasConnections(database));
    signal.reset();
    try std.testing.expect(!server.awaitCloses(database, queued.id));
    holder.close_now.store(true, .release);
    agent.runUntil(&signal.flag);
    try std.testing.expect(server.awaitCloses(database, queued.id));

    const opened = try server.openConnection(database, 2, true, allocator, agent.endpoint());
    try std.testing.expectEqual(@as(u64, 1), opened.old_version);
    opened.connection.releaseHeapOwnership();
    server.dequeue(database, queued.id);
    while (!holder.done.load(.acquire)) std.Thread.yield() catch {};
    if (holder.failed) |err| return err;
}

test "IndexedDB a versionchange whose agent's loop has ended counts as acknowledged" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    // The "other thread" agent: its loop is closed, so a post is dropped.
    var gone = FakeAgent.init(allocator);
    defer gone.deinit();
    gone.thread = otherThreadId();
    gone.close();
    var mine = FakeAgent.init(allocator);
    defer mine.deinit();
    const database = try server.uniqueDatabase(key(), "dropped");
    defer server.release(database);
    const opened = try server.openConnection(database, 1, false, allocator, gone.endpoint());
    defer opened.connection.releaseHeapOwnership();
    var signal: Signal = .{};
    const queued = try server.enqueue(database, mine.endpoint(), signal.client());
    const start = try server.start(database, queued.id, 2, false, allocator);
    allocator.free(start.proceed.local);
    // Its drop end acknowledged it at once.
    try std.testing.expect(server.awaitAcknowledgements(database, queued.id));
    server.dequeue(database, queued.id);
}

/// A thread id that is not this thread's (for an agent whose loop never runs).
fn otherThreadId() std.Thread.Id {
    var id: std.Thread.Id = undefined;
    const thread = std.Thread.spawn(.{}, struct {
        fn run(out: *std.Thread.Id) void {
            out.* = std.Thread.getCurrentId();
        }
    }.run, .{&id}) catch unreachable;
    thread.join();
    return id;
}

test "IndexedDB a request withdrawn mid-upgrade keeps the head until its upgrade is rolled back" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    var agent = FakeAgent.init(allocator);
    defer agent.deinit();
    const database = try server.uniqueDatabase(key(), "abandoned");
    defer server.release(database);

    // The worker's request: at the head, mid-upgrade of a new database.
    var first_signal: Signal = .{};
    const first = try server.enqueue(database, agent.endpoint(), first_signal.client());
    const start = try server.start(database, first.id, 1, false, allocator);
    allocator.free(start.proceed.local);
    const opened = try server.openConnection(database, 1, true, allocator, agent.endpoint());
    const connection = opened.connection;
    const upgrade = try allocator.create(idb.IDBTransaction);
    upgrade.* = idb.IDBTransaction.init(allocator, connection, &.{}, .versionchange);
    try upgrade.register();
    connection.version_change_transaction = upgrade;
    const store = try connection.createObjectStore("should-not-be-created", .{});
    store.deinit();
    allocator.destroy(store);

    // The page's request waits behind it.
    var second_signal: Signal = .{};
    const second = try server.enqueue(database, agent.endpoint(), second_signal.client());
    try std.testing.expect(!second.head);

    // The worker ends: its request withdraws, but its upgrade has not been
    // rolled back yet - the page's request is not told to go on.
    server.withdraw(database, first.id);
    _ = agent.drain();
    try std.testing.expectEqual(@as(usize, 0), second_signal.notes);
    connection.closePending();

    // The upgrade aborts (the worker's teardown): rolled back, then the
    // queue advances.
    try upgrade.abort();
    try std.testing.expectEqual(@as(usize, 1), second_signal.notes);
    connection.version_change_transaction = null;
    upgrade.releaseHeapOwnership();
    connection.releaseHeapOwnership();

    // The page sees the version unchanged and no store.
    const page_start = try server.start(database, second.id, 1, false, allocator);
    allocator.free(page_start.proceed.local);
    try std.testing.expectEqual(@as(u64, 0), page_start.proceed.old_version);
    try std.testing.expect(server.awaitCloses(database, second.id));
    const page = try server.openConnection(database, 1, true, allocator, agent.endpoint());
    defer page.connection.releaseHeapOwnership();
    const names = try page.connection.objectStoreNames();
    defer allocator.free(names);
    try std.testing.expectEqual(@as(usize, 0), names.len);
    server.dequeue(database, second.id);
}

/// A readwrite transaction on its own thread, holding one store until told
/// to commit.
const Writer = struct {
    server: *idb.IDBServer,
    connection: *idb.IDBDatabase,
    started: std.atomic.Value(bool) = .init(false),
    commit_now: std.atomic.Value(bool) = .init(false),
    failed: ?anyerror = null,

    fn run(self: *Writer) void {
        self.steps() catch |err| {
            self.failed = err;
        };
    }

    fn steps(self: *Writer) !void {
        const transaction = try self.connection.transaction(&.{"s"}, .readwrite, .{});
        defer {
            transaction.deinit();
            std.testing.allocator.destroy(transaction);
        }
        try std.testing.expect(transaction.canStart());
        self.started.store(true, .release);
        while (!self.commit_now.load(.acquire)) std.Thread.yield() catch {};
        try transaction.commit();
    }
};

test "IndexedDB the transaction scheduler spans threads: a readonly waits for another thread's readwrite" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    var agent = FakeAgent.init(allocator);
    defer agent.deinit();
    const setup = try openAlone(&server, &agent, "scheduler", 1);
    {
        var upgrade = idb.IDBTransaction.init(allocator, setup, &.{}, .versionchange);
        defer upgrade.deinit();
        setup.version_change_transaction = &upgrade;
        const store = try setup.createObjectStore("s", .{});
        store.deinit();
        allocator.destroy(store);
        try upgrade.commit();
        setup.version_change_transaction = null;
    }

    // The writer's connection and transaction, on another thread.
    var writer: Writer = .{ .server = &server, .connection = setup };
    const thread = try std.Thread.spawn(.{}, Writer.run, .{&writer});
    while (!writer.started.load(.acquire)) std.Thread.yield() catch {};

    // This thread's connection and readonly transaction: it waits, and the
    // writer's commit wakes it - by a task of this thread's loop.
    const reader_database = try server.uniqueDatabase(key(), "scheduler");
    defer server.release(reader_database);
    const reader_connection = (try server.openConnection(reader_database, 1, false, allocator, agent.endpoint())).connection;
    defer reader_connection.releaseHeapOwnership();
    const read = try reader_connection.transaction(&.{"s"}, .readonly, .{});
    defer {
        read.deinit();
        allocator.destroy(read);
    }
    var woken: Signal = .{};
    read.wake_hook = .{ .context = &woken, .call = struct {
        fn call(context: *anyopaque) void {
            const signal: *Signal = @ptrCast(@alignCast(context));
            signal.flag.store(true, .release);
        }
    }.call };
    try std.testing.expect(!read.canStart());
    writer.commit_now.store(true, .release);
    thread.join();
    if (writer.failed) |err| return err;
    agent.runUntil(&woken.flag);
    try std.testing.expect(read.canStart());
    try read.commit();
    setup.releaseHeapOwnership();
}

test "IndexedDB an execution context's end closes its connections, once their transactions finish" {
    const allocator = std.testing.allocator;
    var server = idb.IDBServer.init(allocator);
    defer server.deinit();
    var agent = FakeAgent.init(allocator);
    defer agent.deinit();
    const database = try server.uniqueDatabase(key(), "environment");
    defer server.release(database);
    // Two contexts on one thread (a page and its frame); the frame's
    // connection has a transaction that has not finished.
    var page_context: u8 = 0;
    var frame_context: u8 = 0;
    var page_endpoint = agent.endpoint();
    page_endpoint.environment = &page_context;
    var frame_endpoint = agent.endpoint();
    frame_endpoint.environment = &frame_context;
    const page = (try server.openConnection(database, 1, false, allocator, page_endpoint)).connection;
    defer page.releaseHeapOwnership();
    const frame = (try server.openConnection(database, 1, false, allocator, frame_endpoint)).connection;
    defer frame.releaseHeapOwnership();
    var setup = idb.IDBTransaction.init(allocator, page, &.{}, .versionchange);
    page.version_change_transaction = &setup;
    const store = try page.createObjectStore("s", .{});
    store.deinit();
    allocator.destroy(store);
    try setup.commit();
    page.version_change_transaction = null;
    setup.deinit();
    const unfinished = try frame.transaction(&.{"s"}, .readonly, .{});
    defer {
        unfinished.deinit();
        allocator.destroy(unfinished);
    }

    // A deletion waits for both connections.
    var signal: Signal = .{};
    const queued = try server.enqueue(database, agent.endpoint(), signal.client());
    const start = try server.start(database, queued.id, null, true, allocator);
    allocator.free(start.proceed.local);
    try std.testing.expect(!server.awaitCloses(database, queued.id));

    // The page's context ends: its idle connection is closed at once; the
    // frame's stays.
    server.closeEnvironment(&page_context);
    try std.testing.expectEqual(@as(usize, 0), signal.notes);
    try std.testing.expect(server.hasConnections(database));
    // The frame's context ends: its connection is close-pending - no
    // versionchange reaches it - until its transaction finishes (a realm
    // that runs no task again aborts it).
    server.closeEnvironment(&frame_context);
    try std.testing.expect(server.versionChangeWanted(database, frame.connection_id) == null);
    try std.testing.expect(server.hasConnections(database));
    try unfinished.abort();
    try std.testing.expectEqual(@as(usize, 1), signal.notes);
    try std.testing.expect(server.awaitCloses(database, queued.id));
    try std.testing.expectEqual(@as(u64, 1), server.deleteDatabase(database));
    server.dequeue(database, queued.id);
}
