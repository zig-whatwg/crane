//! WorkerRegistry.ownsAny (lane bfcache-b): the back/forward cache keeps no
//! page that owns a dedicated worker that has not ended.
//!
//! No thread runs here: the link is made and never spawned.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");

test "ownsAny answers for the realm that owns a worker that has not ended" {
    const sink = try runtime.TaskSink.create(testing.allocator);
    defer sink.release();
    var registry = html.WorkerRegistry.init(testing.allocator);
    defer registry.deinit();
    // Two realms, as owners: compared, never dereferenced.
    var realm_a: u8 = 0;
    var realm_b: u8 = 0;
    try testing.expect(!registry.ownsAny(&realm_a));
    const link = try html.WorkerLink.create(testing.allocator, sink);
    defer link.release();
    link.owner_realm = &realm_a;
    try registry.register(link);
    try testing.expect(registry.ownsAny(&realm_a));
    try testing.expect(!registry.ownsAny(&realm_b));
    // Ended: no longer a worker the realm owns.
    link.state.store(.ended, .release);
    try testing.expect(!registry.ownsAny(&realm_a));
    registry.unregister(link);
}
