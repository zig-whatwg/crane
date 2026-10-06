//! HTML's shared worker manager (html.worker_host.SharedWorkerManager): the
//! SharedWorker constructor's match (step 11.2: same constructor storage key,
//! constructor URL and name, closing flag false), the owner set (§ 10.2.3:
//! a Document joins when it makes or connects to a worker, and leaves when it
//! is destroyed), and "closing orphan workers" - a worker whose owner set
//! empties is closed, and never matched again.
//!
//! No thread runs here: the links are made and never spawned, as the
//! manager only reads their closing flag and terminates them.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const SharedWorkerManager = html.worker_host.SharedWorkerManager;
const WorkerLink = html.WorkerLink;

const key: SharedWorkerManager.Key = .{
    .storage_key = "https://web-platform.test:8443",
    .url = "https://web-platform.test:8443/workers/w.js",
    .name = "n",
};

/// Two Documents' realms, as owners: compared, never dereferenced.
var document_a: u8 = 0;
var document_b: u8 = 0;
var host_data: u8 = 0;

const classic: SharedWorkerManager.Options = .{ .worker_type = .classic, .credentials = .same_origin };

fn makeLink(sink: *runtime.TaskSink) !*WorkerLink {
    return WorkerLink.create(testing.allocator, sink);
}

test "a constructor finds a running worker by its key, and its Document joins the owner set" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try makeLink(sink);
    defer link.release();
    try manager.add(key, classic, link, &host_data, &document_a);
    try testing.expectEqual(@as(usize, 1), manager.ownerCount(link));

    // Another name: no match.
    var other = key;
    other.name = "m";
    try testing.expect((try manager.connect(other, classic, &document_b)) == null);

    const found = (try manager.connect(key, classic, &document_b)).?;
    defer found.link.release();
    try testing.expect(found.matched);
    try testing.expectEqual(link, found.link);
    try testing.expectEqual(@as(*anyopaque, &host_data), found.host);
    try testing.expectEqual(@as(usize, 2), manager.ownerCount(link));

    // The same Document again: the owner set is a set.
    const again = (try manager.connect(key, classic, &document_b)).?;
    again.link.release();
    try testing.expectEqual(@as(usize, 2), manager.ownerCount(link));
}

test "a type or credentials mismatch is found but adds no owner" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try makeLink(sink);
    defer link.release();
    try manager.add(key, classic, link, &host_data, &document_a);

    const by_type = (try manager.connect(key, .{ .worker_type = .module, .credentials = .same_origin }, &document_b)).?;
    by_type.link.release();
    try testing.expect(!by_type.matched);
    const by_credentials = (try manager.connect(key, .{ .worker_type = .classic, .credentials = .include }, &document_b)).?;
    by_credentials.link.release();
    try testing.expect(!by_credentials.matched);
    try testing.expectEqual(@as(usize, 1), manager.ownerCount(link));
}

test "a worker whose closing flag is set is never matched" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try makeLink(sink);
    defer link.release();
    try manager.add(key, classic, link, &host_data, &document_a);
    // close() in the worker.
    try testing.expect(link.requestClose());
    try testing.expect((try manager.connect(key, classic, &document_b)) == null);
    // It is still known until its thread has ended.
    try testing.expectEqual(@as(usize, 1), manager.count());
    manager.remove(link);
    try testing.expectEqual(@as(usize, 0), manager.count());
}

test "a Document's end leaves the owner set; the worker whose owner set empties is closed" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const shared = try makeLink(sink);
    defer shared.release();
    const alone = try makeLink(sink);
    defer alone.release();
    var other_key = key;
    other_key.name = "alone";
    try manager.add(key, classic, shared, &host_data, &document_a);
    const found = (try manager.connect(key, classic, &document_b)).?;
    found.link.release();
    try manager.add(other_key, classic, alone, &host_data, &document_b);

    // Document A goes: the shared worker keeps B; nothing is closed.
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&document_a, null));
    try testing.expect(shared.runsTasks());
    try testing.expectEqual(@as(usize, 1), manager.ownerCount(shared));

    // Document B goes: both workers are orphans now, and both are closed.
    try testing.expectEqual(@as(usize, 2), manager.removeOwner(&document_b, null));
    try testing.expect(!shared.runsTasks());
    try testing.expect(!alone.runsTasks());
    try testing.expect((try manager.connect(key, classic, &document_a)) == null);

    // A realm that owns nothing (a worker's) changes nothing.
    var worker_realm: u8 = 0;
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&worker_realm, null));
}

test "the manager is a supplement of its Browser's scope, found through a realm" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const made = try scope.of(SharedWorkerManager);
    try testing.expectEqual(made, scope.existing(SharedWorkerManager).?);
}

test "a worker with an extended lifetime outlives its owner set emptying until the timeout, unless an owner joins" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try makeLink(sink);
    defer link.release();
    const extended: SharedWorkerManager.Options = .{ .worker_type = .classic, .credentials = .same_origin, .extended_lifetime = true };
    try manager.add(key, extended, link, &host_data, &document_a);

    // Step 11.4: an extended lifetime that differs is a mismatch.
    const plain = (try manager.connect(key, classic, &document_b)).?;
    plain.link.release();
    try testing.expect(!plain.matched);

    // The owner set empties: not closed now - the caller arms the timeout.
    var orphans: std.ArrayListUnmanaged(SharedWorkerManager.Orphan) = .empty;
    defer orphans.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&document_a, &orphans));
    try testing.expectEqual(@as(usize, 1), orphans.items.len);
    try testing.expect(link.runsTasks());
    const first = orphans.items[0];
    defer first.link.release();

    // A Document connects within the timeout: the timer finds an owner.
    const found = (try manager.connect(key, extended, &document_b)).?;
    found.link.release();
    try testing.expect(found.matched);
    try testing.expect(!manager.closeIfStillOrphaned(first.link, first.epoch));
    try testing.expect(link.runsTasks());

    // It empties again: the earlier timer's epoch is stale, the new one closes it.
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&document_b, &orphans));
    const second = orphans.items[1];
    defer second.link.release();
    try testing.expect(!manager.closeIfStillOrphaned(first.link, first.epoch));
    try testing.expect(manager.closeIfStillOrphaned(second.link, second.epoch));
    try testing.expect(!link.runsTasks());
}

test "with no list to arm, an extended lifetime's orphan is closed at once" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();
    const link = try makeLink(sink);
    defer link.release();
    try manager.add(key, .{ .worker_type = .classic, .credentials = .same_origin, .extended_lifetime = true }, link, &host_data, &document_a);
    try testing.expectEqual(@as(usize, 1), manager.removeOwner(&document_a, null));
    try testing.expect(!link.runsTasks());
}

test "two threads: the window thread connects and drops owners while a worker thread's realm ends ask the manager" {
    // The manager's steps run on the Browser's window thread; every realm's
    // end - a worker's on its own thread - asks it to drop that realm from
    // the owner sets (sharedWorkerOwnerGone). Its mutex makes both safe; a
    // list mutated from two threads without it loses entries or crashes.
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var manager = SharedWorkerManager.init(testing.allocator);
    defer manager.deinit();

    const Worker = struct {
        manager: *SharedWorkerManager,
        stop: std.atomic.Value(bool) = .init(false),
        asked: usize = 0,

        fn run(self: *@This()) void {
            var worker_realm: u8 = 0;
            while (!self.stop.load(.acquire)) {
                // A worker realm owns no shared worker: nothing closes.
                std.debug.assert(self.manager.removeOwner(&worker_realm, null) == 0);
                _ = self.manager.count();
                self.asked += 1;
            }
        }
    };
    var worker: Worker = .{ .manager = &manager };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&worker});

    var documents: [8]u8 = undefined;
    var round: usize = 0;
    while (round < 2000) : (round += 1) {
        const link = try makeLink(sink);
        defer link.release();
        var round_key = key;
        var name_buffer: [16]u8 = undefined;
        round_key.name = try std.fmt.bufPrint(&name_buffer, "w{d}", .{round % 4});
        try manager.add(round_key, classic, link, &host_data, &documents[round % documents.len]);
        if ((try manager.connect(round_key, classic, &documents[(round + 1) % documents.len]))) |found| found.link.release();
        _ = manager.removeOwner(&documents[round % documents.len], null);
        _ = manager.removeOwner(&documents[(round + 1) % documents.len], null);
        try testing.expect(!link.runsTasks());
        manager.remove(link);
    }
    worker.stop.store(true, .release);
    thread.join();
    try testing.expectEqual(@as(usize, 0), manager.count());
    try testing.expect(worker.asked > 0);
}
