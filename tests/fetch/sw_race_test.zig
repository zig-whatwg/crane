//! Service Workers Handle Fetch 13.3.4, "race-network-and-fetch-handler", as
//! the fetching thread runs it: a request whose route hands it back as a
//! race (`Route.Start.race`) is fetched from the network beside the service
//! worker's fetch event - a sibling AsyncFetch on the same agent's fetches -
//! and the first usable answer is the fetch's:
//!
//! 1. the network's ok response before the worker answers: the network wins,
//!    and the worker's answer, when it comes, is freed (its event still runs);
//! 2. the worker's response (or network error) first: the network side is
//!    terminated, its transfer cancelled;
//! 3. the worker falls back: the race's response, whatever its status, with no
//!    second network request (Create Fetch Event and Dispatch step 21.3);
//! 4. the network's non-ok response first: kept, and the worker decides.
//!
//! And a fetch whose client goes away mid-race ends both fetches. Each case
//! runs on `std.testing.allocator`: whatever a losing side leaves is a leak.
//! The network's timing comes from the server (`/split-head` holds its
//! response until the test releases it), never from the clock.

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
const Call = service_worker_fetch.Call;
const TestServer = @import("test_server.zig").TestServer;

/// The route's owner: every request it is asked about is handed back as a
/// race, and the test answers the call as the service worker would.
const RacingWorkers = struct {
    asked: u32 = 0,
    /// The worker side's reference to the last call.
    call: ?*Call = null,

    fn route(self: *RacingWorkers) fetch.internal.ServiceWorkerRoute {
        return .{ .context = self, .client = 9, .handle = handle };
    }

    fn handle(context: *anyopaque, request: *const InternalRequest, client: u64) std.mem.Allocator.Error!service_worker_fetch.Route.Start {
        const self: *RacingWorkers = @ptrCast(@alignCast(context));
        _ = request;
        std.debug.assert(client == 9);
        self.asked += 1;
        const call = try Call.create(testing.allocator);
        self.call = call;
        return .{ .race = call };
    }

    /// The worker answers the last call and lets go of it.
    fn answer(self: *RacingWorkers, value: Call.Answer) void {
        const call = self.call.?;
        self.call = null;
        call.answer(value);
        call.release();
    }

    /// The worker side lets go without answering (after the test checked
    /// the call).
    fn drop(self: *RacingWorkers) void {
        const call = self.call orelse return;
        self.call = null;
        call.answer(.fallback);
        call.release();
    }
};

/// A client that records what it heard.
const Recorder = struct {
    alive: bool = true,
    done_calls: usize = 0,
    gone_calls: usize = 0,
    finished_calls: usize = 0,
    failed: bool = false,
    network_error: bool = false,
    status: u16 = 0,
    body: [64]u8 = undefined,
    body_len: usize = 0,

    fn client(self: *Recorder) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = isAlive, .gone = gone, .finished = finished };
    }

    fn done(context: *anyopaque, result: algorithms.FetchError!algorithms.FetchResult) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        self.done_calls += 1;
        var r = result catch {
            self.failed = true;
            return;
        };
        defer r.deinit();
        self.network_error = r.response.response_type == .@"error";
        self.status = r.response.status;
        if (r.response.body) |body| {
            const bytes = body.getBytes();
            const n = @min(bytes.len, self.body.len);
            @memcpy(self.body[0..n], bytes[0..n]);
            self.body_len = n;
        }
    }

    fn isAlive(context: *anyopaque) bool {
        const self: *Recorder = @ptrCast(@alignCast(context));
        return self.alive;
    }

    fn gone(context: *anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        self.gone_calls += 1;
    }

    fn finished(context: *anyopaque) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        self.finished_calls += 1;
    }

    fn bodyText(self: *const Recorder) []const u8 {
        return self.body[0..self.body_len];
    }
};

fn raceRequest(server: *TestServer, workers: *RacingWorkers, path: []const u8) !*InternalRequest {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base, path });
    const request = try InternalRequest.init(testing.allocator, url);
    errdefer request.deinit();
    try request.setOrigin(base);
    request.mode = .cors;
    request.service_worker = workers.route();
    return request;
}

fn workerResponse(status: u16) !*InternalResponse {
    const response = try InternalResponse.init(testing.allocator);
    response.status = status;
    return response;
}

/// Turn the network step until `done` holds or `limit_ms` passes.
fn turnUntil(fetches: *AgentFetches, context: anytype, comptime done: fn (@TypeOf(context)) bool, limit_ms: i64) bool {
    const deadline = clock.monotonicMillis() + limit_ms;
    while (!done(context)) {
        if (clock.monotonicMillis() >= deadline) return false;
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    return true;
}

fn heard(recorder: *const Recorder) bool {
    return recorder.done_calls > 0 or recorder.gone_calls > 0;
}

fn over(recorder: *const Recorder) bool {
    return recorder.finished_calls > 0 or recorder.gone_calls > 0;
}

fn idle(fetches: *const AgentFetches) bool {
    return fetches.inFlight() == 0;
}

fn raceKeepsNetwork(f: *const AsyncFetch) bool {
    return f.raceHasNetworkResponse();
}

test "race 1: the network's ok response before the worker answers wins; the worker's late answer is freed and its event was not abandoned" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    _ = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/get"), .{}, &fetches, recorder.client());
    try testing.expectEqual(@as(u32, 1), workers.asked);
    // The fetch and the race's network side.
    try testing.expectEqual(@as(usize, 2), fetches.inFlight());

    try testing.expect(turnUntil(&fetches, &recorder, over, 5_000));
    try testing.expectEqual(@as(usize, 1), recorder.done_calls);
    try testing.expect(!recorder.failed and !recorder.network_error);
    try testing.expectEqual(@as(u16, 200), recorder.status);
    try testing.expect(std.mem.indexOf(u8, recorder.bodyText(), "\"/get\"") != null);
    try testing.expect(turnUntil(&fetches, &fetches, idle, 5_000));
    // The worker's fetch event still runs (Create Fetch Event and Dispatch
    // is in parallel): the call was not abandoned, only lost.
    try testing.expect(!workers.call.?.isAbandoned());
    // Its answer, coming late, is freed (std.testing.allocator would report
    // the response leaked otherwise).
    workers.answer(.{ .response = .{ .response = try workerResponse(201) } });
}

test "race 2: the worker's response before the network wins; the network side is terminated" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    defer server.releaseHead();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    _ = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/split-head"), .{}, &fetches, recorder.client());
    // The network side has reached the server, which holds its response.
    const Started = struct {
        fn check(s: *TestServer) bool {
            return s.headStarted();
        }
    };
    const deadline = clock.monotonicMillis() + 5_000;
    while (!Started.check(server) and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expect(server.headStarted());
    workers.answer(.{ .response = .{ .response = try workerResponse(201) } });
    try testing.expect(turnUntil(&fetches, &recorder, over, 5_000));
    try testing.expectEqual(@as(u16, 201), recorder.status);
    // Both fetches are gone at once: the network side's transfer was
    // cancelled, not waited for.
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "race 2b: the worker's network error before the network is the fetch's" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    defer server.releaseHead();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    _ = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/split-head"), .{}, &fetches, recorder.client());
    workers.answer(.network_error);
    try testing.expect(turnUntil(&fetches, &recorder, heard, 5_000));
    try testing.expect(recorder.network_error);
    try testing.expect(turnUntil(&fetches, &fetches, idle, 5_000));
}

test "race 3: a fallback answer takes the race's response, whatever its status - no second network request" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    _ = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/status/404"), .{}, &fetches, recorder.client());
    // The worker falls back before the network has answered.
    workers.answer(.fallback);
    try testing.expect(turnUntil(&fetches, &recorder, over, 5_000));
    try testing.expectEqual(@as(u16, 404), recorder.status);
    // Asked once: the race's network side (service-workers mode "none")
    // asked no one, and the fallback took its response rather than going
    // through HTTP fetch step 4 again.
    try testing.expectEqual(@as(u32, 1), workers.asked);
    try testing.expect(turnUntil(&fetches, &fetches, idle, 5_000));
}

test "race 4: the network's non-ok response first is kept, and the worker's later response wins" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    const raced = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/status/404"), .{}, &fetches, recorder.client());
    try testing.expect(turnUntil(&fetches, raced, raceKeepsNetwork, 5_000));
    // Not ok: the fetch waits for the worker.
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);
    workers.answer(.{ .response = .{ .response = try workerResponse(201) } });
    try testing.expect(turnUntil(&fetches, &recorder, over, 5_000));
    try testing.expectEqual(@as(u16, 201), recorder.status);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "race 5: a fetch whose client goes away mid-race ends both fetches, and the worker's call is abandoned" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    defer server.releaseHead();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var workers: RacingWorkers = .{};
    var recorder: Recorder = .{};

    _ = try AsyncFetch.start(testing.allocator, try raceRequest(server, &workers, "/split-head"), .{}, &fetches, recorder.client());
    try testing.expectEqual(@as(usize, 2), fetches.inFlight());
    _ = fetches.pump();
    recorder.alive = false;
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 1), recorder.gone_calls);
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
    try testing.expect(workers.call.?.isAbandoned());
    workers.drop();
}
