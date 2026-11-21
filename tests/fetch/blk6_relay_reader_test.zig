//! A request body another thread writes for this agent's realm - a page's
//! stream body handed to a service worker as it arrives (HTTP fetch step 3.2,
//! service_worker_fetch.Upload) - read through a pipe the agent's loop fills
//! from the relay each turn (AgentFetches.readRelay).
//!
//! fetch() read a stream body to its end before it started, and a service
//! worker's copy of a request could not carry a body still arriving: a page
//! whose stream never closed never reached the worker
//! (service-workers/service-worker/fetch-request-body-cancel.https.html timed
//! out). The worker's realm now reads the body as it comes, and cancelling it
//! there tells the writer.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const AgentFetches = fetch.algorithms.AgentFetches;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const BodyRelay = service_worker_fetch.BodyRelay;

test "a relayed request body reaches its pipe as it is written, then its end, and the reader goes" {
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    const relay = try BodyRelay.create(testing.allocator);
    const pipe = try fetches.readRelay(relay);
    defer pipe.release();
    // The reader keeps the agent's loop turning while the body comes.
    try testing.expectEqual(@as(usize, 1), fetches.inFlight());

    try testing.expect(relay.write("hello "));
    _ = fetches.pump();
    const first = try pipe.take();
    defer testing.allocator.free(first);
    try testing.expectEqualStrings("hello ", first);
    try testing.expectEqual(fetch.internal.body_pipe.State.open, pipe.state);

    try testing.expect(relay.write("world"));
    relay.close();
    relay.release(); // the writer's
    _ = fetches.pump();
    const rest = try pipe.take();
    defer testing.allocator.free(rest);
    try testing.expectEqualStrings("world", rest);
    try testing.expectEqual(fetch.internal.body_pipe.State.closed, pipe.state);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "cancelling the relayed body's last reader cancels the relay: the writer stops" {
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    const relay = try BodyRelay.create(testing.allocator);
    const pipe = try fetches.readRelay(relay);
    try testing.expect(relay.write("1"));
    _ = fetches.pump();
    // event.request.body.cancel(): the stream lets its pipe go.
    pipe.release();
    try testing.expect(relay.isCancelled());
    try testing.expect(!relay.write("2"));
    // The reader goes at the next turn.
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    relay.release(); // the writer's
}

test "a relayed body that fails errors its pipe; one left unread at the agent's end stops its writer" {
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    {
        var fetches = AgentFetches.init(testing.allocator);
        defer fetches.deinit();
        const relay = try BodyRelay.create(testing.allocator);
        const pipe = try fetches.readRelay(relay);
        defer pipe.release();
        relay.fail();
        relay.release();
        _ = fetches.pump();
        try testing.expectEqual(fetch.internal.body_pipe.State.errored, pipe.state);
    }
    {
        var fetches = AgentFetches.init(testing.allocator);
        const relay = try BodyRelay.create(testing.allocator);
        const pipe = try fetches.readRelay(relay);
        defer pipe.release();
        fetches.deinit();
        try testing.expect(relay.isCancelled());
        try testing.expectEqual(fetch.internal.body_pipe.State.errored, pipe.state);
        relay.release();
    }
}
