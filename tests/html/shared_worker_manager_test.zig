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
    try manager.add(key, .classic, .same_origin, link, &host_data, &document_a);
    try testing.expectEqual(@as(usize, 1), manager.ownerCount(link));

    // Another name: no match.
    var other = key;
    other.name = "m";
    try testing.expect((try manager.connect(other, .classic, .same_origin, &document_b)) == null);

    const found = (try manager.connect(key, .classic, .same_origin, &document_b)).?;
    defer found.link.release();
    try testing.expect(found.matched);
    try testing.expectEqual(link, found.link);
    try testing.expectEqual(@as(*anyopaque, &host_data), found.host);
    try testing.expectEqual(@as(usize, 2), manager.ownerCount(link));

    // The same Document again: the owner set is a set.
    const again = (try manager.connect(key, .classic, .same_origin, &document_b)).?;
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
    try manager.add(key, .classic, .same_origin, link, &host_data, &document_a);

    const by_type = (try manager.connect(key, .module, .same_origin, &document_b)).?;
    by_type.link.release();
    try testing.expect(!by_type.matched);
    const by_credentials = (try manager.connect(key, .classic, .include, &document_b)).?;
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
    try manager.add(key, .classic, .same_origin, link, &host_data, &document_a);
    // close() in the worker.
    try testing.expect(link.requestClose());
    try testing.expect((try manager.connect(key, .classic, .same_origin, &document_b)) == null);
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
    try manager.add(key, .classic, .same_origin, shared, &host_data, &document_a);
    const found = (try manager.connect(key, .classic, .same_origin, &document_b)).?;
    found.link.release();
    try manager.add(other_key, .classic, .same_origin, alone, &host_data, &document_b);

    // Document A goes: the shared worker keeps B; nothing is closed.
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&document_a));
    try testing.expect(shared.runsTasks());
    try testing.expectEqual(@as(usize, 1), manager.ownerCount(shared));

    // Document B goes: both workers are orphans now, and both are closed.
    try testing.expectEqual(@as(usize, 2), manager.removeOwner(&document_b));
    try testing.expect(!shared.runsTasks());
    try testing.expect(!alone.runsTasks());
    try testing.expect((try manager.connect(key, .classic, .same_origin, &document_a)) == null);

    // A realm that owns nothing (a worker's) changes nothing.
    var worker_realm: u8 = 0;
    try testing.expectEqual(@as(usize, 0), manager.removeOwner(&worker_realm));
}

test "the manager is a supplement of its Browser's scope, found through a realm" {
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const made = try scope.of(SharedWorkerManager);
    try testing.expectEqual(made, scope.existing(SharedWorkerManager).?);
}
