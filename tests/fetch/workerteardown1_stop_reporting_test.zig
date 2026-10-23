//! A fetch whose global has begun to end reports nothing more: its body's
//! end, when its last reader goes after, reports no Resource Timing
//! (AgentFetches.stopReporting; lane workerteardown1).
//!
//! A worker realm's end freed the realm's objects first and only then swept
//! the fetches its realm left (worker_realm.destroyWorkerRealmIn's `retire`).
//! An object freed in between - a response body's stream, an unread
//! Response, an XMLHttpRequest, an EventSource - ended its fetch's body, and
//! the fetch reported Resource Timing to the worker's global scope, which the
//! same teardown may already have freed: a SIGSEGV in Instance.stateAs under
//! Performance.performanceOfRealm (fetch/api/basic/stream-response.any.js
//! [worker]). The worker host now mutes its fetches at the start of the
//! realm's end (WorkerHost.teardownRealm), as Blink prevents a loader's
//! notifications when its context is destroyed (FetchManager::Loader::Dispose)
//! before the global scope is disposed; the fetch group is still terminated
//! by the sweep after.
//!
//! The mute is called only where it exists, so the red run fails on what is
//! reported rather than on a missing name.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const algorithms = fetch.algorithms;
const AsyncFetch = algorithms.AsyncFetch;
const AgentFetches = algorithms.AgentFetches;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const TestServer = @import("test_server.zig").TestServer;

/// The mute, where it exists.
fn stopReporting(fetches: *AgentFetches) void {
    if (comptime @hasDecl(AgentFetches, "stopReporting")) fetches.stopReporting();
}

/// What the request's timing reporter (its client's global) was told.
const Reports = struct {
    count: usize = 0,

    fn reporter(self: *Reports) fetch.internal.request.TimingReporter {
        return .{ .context = self, .report = receive };
    }

    fn receive(context: *anyopaque, _: *const fetch.internal.request.TimingReport) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
    }
};

/// A client that records what it heard, and keeps the response it was
/// handed - its body still arriving - as a Response does.
const Client = struct {
    alive: bool = true,
    done_calls: usize = 0,
    gone_calls: usize = 0,
    finished_calls: usize = 0,
    result: ?algorithms.FetchResult = null,

    fn client(self: *Client) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = isAlive, .gone = gone, .finished = finished };
    }

    fn done(context: *anyopaque, outcome: algorithms.FetchError!algorithms.FetchResult) void {
        const self: *Client = @ptrCast(@alignCast(context));
        self.done_calls += 1;
        self.result = outcome catch null;
    }

    fn isAlive(context: *anyopaque) bool {
        const self: *Client = @ptrCast(@alignCast(context));
        return self.alive;
    }

    fn gone(context: *anyopaque) void {
        const self: *Client = @ptrCast(@alignCast(context));
        self.gone_calls += 1;
    }

    fn finished(context: *anyopaque) void {
        const self: *Client = @ptrCast(@alignCast(context));
        self.finished_calls += 1;
    }

    /// The response goes - as the realm's end frees a Response or its
    /// body's stream - and with it the body's last reader.
    fn dropResponse(self: *Client) void {
        if (self.result) |*r| r.deinit();
        self.result = null;
    }
};

fn reportedRequest(url: []const u8, origin: []const u8, reports: *Reports) !*InternalRequest {
    const request = try InternalRequest.init(testing.allocator, url);
    errdefer request.deinit();
    try request.setOrigin(origin);
    request.mode = .same_origin;
    request.initiator_type = .fetch;
    request.timing_reporter = reports.reporter();
    return request;
}

fn turnUntilHandedOver(fetches: *AgentFetches, c: *const Client) !void {
    const deadline = clock.monotonicMillis() + 5_000;
    while (c.done_calls == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 1), c.done_calls);
}

/// A streamed fetch of `/trickle/20` from `server`, handed over with its
/// body still arriving. Returns the fetch.
fn startTrickle(server: *TestServer, fetches: *AgentFetches, reports: *Reports, c: *Client) !*AsyncFetch {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    const request = try reportedRequest(try std.fmt.bufPrint(&url_buf, "{s}/trickle/20", .{base}), base, reports);
    const f = try AsyncFetch.startStreaming(testing.allocator, request, .{}, fetches, c.client());
    try turnUntilHandedOver(fetches, c);
    return f;
}

test "control: a streamed body whose last reader goes reports its timing then" {
    // The path a realm's end takes: freeing the response stops the
    // transfer, and the body's end is reported (AsyncFetch.stopProducing).
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var c: Client = .{};
    defer c.dropResponse();
    _ = try startTrickle(server, &fetches, &reports, &c);
    try testing.expectEqual(@as(usize, 0), reports.count);
    c.dropResponse();
    try testing.expectEqual(@as(usize, 1), reports.count);
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "a streamed body whose global began to end reports nothing when its last reader goes" {
    // AsyncFetch.stopProducing after the mute.
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var c: Client = .{};
    defer c.dropResponse();
    _ = try startTrickle(server, &fetches, &reports, &c);

    stopReporting(&fetches);
    // Muted, not ended: its client hears nothing, and it is still in flight.
    try testing.expectEqual(@as(usize, 0), c.gone_calls);
    try testing.expectEqual(@as(usize, 1), fetches.inFlight());

    // The realm's objects go: the response, and its body's last reader.
    c.dropResponse();
    try testing.expectEqual(@as(usize, 0), reports.count);
    // Over - nobody reads its body - and its client hears so on the next
    // turn, as before.
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 1), c.finished_calls);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "a muted fetch is still terminated with its fetch group once its client is gone, reporting nothing" {
    // The sweep after the realm's end, as before; the body read after it
    // ends with nothing reported either.
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var c: Client = .{};
    defer c.dropResponse();
    _ = try startTrickle(server, &fetches, &reports, &c);

    stopReporting(&fetches);
    c.alive = false;
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 1), c.gone_calls);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    c.dropResponse();
    try testing.expectEqual(@as(usize, 0), reports.count);
}

test "a muted fetch its client terminates mid-body reports nothing" {
    // AsyncFetch.terminateWith after the mute: an XMLHttpRequest or an
    // EventSource freed with the realm cancels its fetch.
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var c: Client = .{};
    defer c.dropResponse();
    const f = try startTrickle(server, &fetches, &reports, &c);

    stopReporting(&fetches);
    f.terminate();
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

/// A route whose "service worker" answers with a relayed body.
const RelayingWorker = struct {
    call: ?*service_worker_fetch.Call = null,

    fn route(self: *RelayingWorker) fetch.internal.ServiceWorkerRoute {
        return .{ .context = self, .client = 3, .handle = handle };
    }

    fn handle(context: *anyopaque, _: *const InternalRequest, _: u64) std.mem.Allocator.Error!service_worker_fetch.Route.Start {
        const self: *RelayingWorker = @ptrCast(@alignCast(context));
        const call = try service_worker_fetch.Call.create(testing.allocator);
        self.call = call;
        return .{ .call = call };
    }
};

/// A fetch answered by a service worker with a body relayed from its
/// thread, handed over with the relay still open. Returns the relay (one
/// reference the caller releases).
fn startRelayed(fetches: *AgentFetches, reports: *Reports, c: *Client, worker: *RelayingWorker) !*service_worker_fetch.BodyRelay {
    const request = try reportedRequest("http://a.test/relayed", "http://a.test", reports);
    request.service_worker = worker.route();
    _ = try AsyncFetch.startStreaming(testing.allocator, request, .{}, fetches, c.client());
    const call = worker.call.?;
    const relay = try service_worker_fetch.BodyRelay.create(testing.allocator);
    const response = try InternalResponse.init(testing.allocator);
    response.status = 200;
    call.answer(.{ .response = .{ .response = response, .body = relay } });
    call.release();
    try turnUntilHandedOver(fetches, c);
    _ = relay.write("hello");
    _ = fetches.pump();
    return relay;
}

test "control: a relayed body whose last reader goes reports its timing then" {
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var worker: RelayingWorker = .{};
    var c: Client = .{};
    defer c.dropResponse();
    const relay = try startRelayed(&fetches, &reports, &c, &worker);
    defer relay.release();
    try testing.expectEqual(@as(usize, 0), reports.count);
    c.dropResponse();
    try testing.expectEqual(@as(usize, 1), reports.count);
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "a relayed body whose global began to end reports nothing when its last reader goes" {
    // AsyncFetch.stopRelay after the mute.
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var worker: RelayingWorker = .{};
    var c: Client = .{};
    defer c.dropResponse();
    const relay = try startRelayed(&fetches, &reports, &c, &worker);
    defer relay.release();

    stopReporting(&fetches);
    try testing.expectEqual(@as(usize, 0), c.gone_calls);
    try testing.expectEqual(@as(usize, 1), fetches.inFlight());

    c.dropResponse();
    try testing.expectEqual(@as(usize, 0), reports.count);
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    try testing.expectEqual(@as(usize, 0), reports.count);
}
