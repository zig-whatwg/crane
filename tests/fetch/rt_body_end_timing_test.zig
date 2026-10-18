//! Fetch "fetch response handover" step 4: the report timing steps run at
//! the end of the body (processResponseEndOfBody), not when the response is
//! handed over - so a streamed body's Resource Timing entry has its sizes,
//! and its end time is the body's end. Chromium's point in time, which Crane
//! follows: the loader's end, when the body has been received or has failed
//! (resource_fetcher.cc HandleLoaderFinish / HandleLoaderError) - not the
//! consumer's read of the last chunk.
//!
//! A service worker's relayed body is such a body too
//! (service-workers/service-worker/resource-timing-bodySize.https.html: the
//! entry's decodedBodySize is the bytes the page read). A fetch its client
//! ends mid-body is reported then, with what arrived (Chromium's
//! HandleLoaderError); one whose client has gone reports nothing.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const algorithms = fetch.algorithms;
const AsyncFetch = algorithms.AsyncFetch;
const AgentFetches = algorithms.AgentFetches;
const FetchJob = algorithms.FetchJob;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const PipeSource = fetch.internal.body_pipe.PipeSource;
const service_worker_fetch = fetch.internal.service_worker_fetch;
const TestServer = @import("test_server.zig").TestServer;

const Reports = struct {
    count: usize = 0,
    encoded: u64 = 0,
    decoded: u64 = 0,
    status: u16 = 0,

    fn reporter(self: *Reports) fetch.internal.request.TimingReporter {
        return .{ .context = self, .report = receive };
    }

    fn receive(context: *anyopaque, timing: *const fetch.internal.request.TimingReport) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        self.encoded = timing.body_info.encoded_size;
        self.decoded = timing.body_info.decoded_size;
        self.status = timing.response_status;
    }
};

fn head(status: u16) !network.NetworkResponse {
    const a = testing.allocator;
    const headers = try a.alloc(network.NetworkResponse.Header, 0);
    return .{ .allocator = a, .status = status, .http_version = .http_1_1, .headers = headers, .body = null, .final_url = null, .total_time_ms = 0, .time_to_first_byte_ms = 0, .redirect_count = 0, .remote_ip = null, .remote_port = null };
}

fn reportedRequest(url: []const u8, reports: *Reports) !*InternalRequest {
    const request = try InternalRequest.init(testing.allocator, url);
    errdefer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .same_origin;
    request.initiator_type = .fetch;
    request.timing_reporter = reports.reporter();
    return request;
}

/// The job's body-end step (absent before it existed: the red run fails on
/// the observed early report instead of a compile error).
fn bodyEnded(job: *FetchJob, bytes: u64) void {
    if (comptime @hasDecl(FetchJob, "bodyEnded")) job.bodyEnded(.{ .encoded = bytes, .decoded = bytes });
}

test "a streamed body's timing report waits for the body's end, and has its sizes" {
    var reports: Reports = .{};
    const request = try reportedRequest("http://a.test/streamed", &reports);
    defer request.deinit();
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    try testing.expect(try job.start() == .network);
    const source = try PipeSource.create(testing.allocator);
    const step = try job.resumeNetworkHead(try head(200), try source.branch());
    try testing.expect(step == .done);
    var result = job.takeResult();
    defer result.deinit();
    // Handed over with its body still arriving: nothing reported yet.
    try testing.expectEqual(@as(usize, 0), reports.count);
    source.push("abc");
    source.push("de");
    source.finish();
    bodyEnded(job, 5);
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqual(@as(u64, 5), reports.encoded);
    try testing.expectEqual(@as(u64, 5), reports.decoded);
    try testing.expectEqual(@as(u16, 200), reports.status);
    // Once.
    bodyEnded(job, 5);
    try testing.expectEqual(@as(usize, 1), reports.count);
}

test "a body that is all there at handover is reported then, as before" {
    var reports: Reports = .{};
    const request = try reportedRequest("http://a.test/whole", &reports);
    defer request.deinit();
    const job = try FetchJob.create(testing.allocator, request, false, .{});
    defer job.destroy();
    try testing.expect(try job.start() == .network);
    var response = try head(200);
    response.body = try testing.allocator.dupe(u8, "hello");
    try testing.expect(try job.resumeNetwork(response) == .done);
    var result = job.takeResult();
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqual(@as(u64, 5), reports.decoded);
}

test "a job that goes before its body ended reports nothing, and frees what it kept" {
    var reports: Reports = .{};
    const request = try reportedRequest("http://a.test/cut", &reports);
    defer request.deinit();
    const source = try PipeSource.create(testing.allocator);
    // The response (and its body's reader) outlives the job, as a page's
    // Response object does; the source ends after the job has gone.
    var result: fetch.algorithms.FetchResult = undefined;
    {
        const job = try FetchJob.create(testing.allocator, request, false, .{});
        defer job.destroy();
        try testing.expect(try job.start() == .network);
        _ = try job.resumeNetworkHead(try head(200), try source.branch());
        result = job.takeResult();
    }
    source.fail(.{ .kind = .aborted });
    result.deinit();
    try testing.expectEqual(@as(usize, 0), reports.count);
}

/// A client that records its end.
const Client = struct {
    alive: bool = true,
    done_calls: usize = 0,
    finished_calls: usize = 0,
    gone_calls: usize = 0,
    body_len: usize = 0,
    /// The response's body, read as the test turns the loop.
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

    /// Read what has arrived of the body (a reader keeps the transfer going).
    fn read(self: *Client) void {
        const r = self.result orelse return;
        const body = r.response.body orelse return;
        const pipe = body.pipe orelse return;
        const bytes = pipe.take() catch return;
        defer testing.allocator.free(bytes);
        self.body_len += bytes.len;
    }

    fn deinit(self: *Client) void {
        if (self.result) |*r| r.deinit();
        self.result = null;
    }
};

fn turnUntilFinished(fetches: *AgentFetches, c: *Client, limit_ms: i64) bool {
    const deadline = clock.monotonicMillis() + limit_ms;
    while (c.finished_calls == 0 and c.gone_calls == 0) {
        if (clock.monotonicMillis() >= deadline) return false;
        _ = fetches.pump();
        c.read();
        clock.sleep(std.time.ns_per_ms);
    }
    c.read();
    return true;
}

test "a fetch on the event loop reports a streamed network body's sizes at its end" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    const request = try InternalRequest.init(testing.allocator, try std.fmt.bufPrint(&url_buf, "{s}/trickle/3", .{base}));
    try request.setOrigin(base);
    request.mode = .same_origin;
    request.initiator_type = .fetch;
    request.timing_reporter = reports.reporter();
    var c: Client = .{};
    defer c.deinit();
    _ = try AsyncFetch.startStreaming(testing.allocator, request, .{}, &fetches, c.client());
    try testing.expect(turnUntilFinished(&fetches, &c, 5_000));
    // Three "chunk\n" chunks.
    try testing.expectEqual(@as(usize, 18), c.body_len);
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqual(@as(u64, 18), reports.decoded);
    try testing.expectEqual(@as(u64, 18), reports.encoded);
}

/// A route whose "service worker" answers at once with a relayed body.
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

test "a service worker's relayed body is reported at its end, with the bytes the page received" {
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var worker: RelayingWorker = .{};
    const request = try reportedRequest("http://a.test/relayed", &reports);
    request.service_worker = worker.route();
    var c: Client = .{};
    defer c.deinit();
    _ = try AsyncFetch.startStreaming(testing.allocator, request, .{}, &fetches, c.client());
    const call = worker.call.?;
    const relay = try service_worker_fetch.BodyRelay.create(testing.allocator);
    const response = try InternalResponse.init(testing.allocator);
    response.status = 200;
    call.answer(.{ .response = .{ .response = response, .body = relay } });
    call.release();
    // Handed over first; the body follows.
    const deadline = clock.monotonicMillis() + 5_000;
    while (c.done_calls == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 1), c.done_calls);
    try testing.expectEqual(@as(usize, 0), reports.count);
    _ = relay.write("hello ");
    _ = relay.write("world");
    relay.close();
    relay.release();
    try testing.expect(turnUntilFinished(&fetches, &c, 5_000));
    try testing.expectEqual(@as(usize, 11), c.body_len);
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expectEqual(@as(u64, 11), reports.decoded);
}

test "a fetch terminated before its body ended reports nothing" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    const request = try InternalRequest.init(testing.allocator, try std.fmt.bufPrint(&url_buf, "{s}/trickle/20", .{base}));
    try request.setOrigin(base);
    request.mode = .same_origin;
    request.initiator_type = .fetch;
    request.timing_reporter = reports.reporter();
    var c: Client = .{};
    defer c.deinit();
    _ = try AsyncFetch.startStreaming(testing.allocator, request, .{}, &fetches, c.client());
    const deadline = clock.monotonicMillis() + 5_000;
    while (c.done_calls == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 1), c.done_calls);
    // The page goes: the fetch is terminated mid-body.
    c.alive = false;
    _ = fetches.pump();
    try testing.expectEqual(@as(usize, 1), c.gone_calls);
    try testing.expectEqual(@as(usize, 0), reports.count);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "a fetch its client terminates mid-body is reported then, with what arrived of the body" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();
    var reports: Reports = .{};
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    const request = try InternalRequest.init(testing.allocator, try std.fmt.bufPrint(&url_buf, "{s}/trickle/20", .{base}));
    try request.setOrigin(base);
    request.mode = .same_origin;
    request.initiator_type = .fetch;
    request.timing_reporter = reports.reporter();
    var c: Client = .{};
    defer c.deinit();
    const f = try AsyncFetch.startStreaming(testing.allocator, request, .{}, &fetches, c.client());
    // Handed over, and the first chunk read.
    const deadline = clock.monotonicMillis() + 5_000;
    while (c.body_len == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        c.read();
        clock.sleep(std.time.ns_per_ms);
    }
    try testing.expect(c.body_len > 0);
    try testing.expectEqual(@as(usize, 0), reports.count);
    // The client stops it (an element that stopped loading, an abort).
    f.terminate();
    try testing.expectEqual(@as(usize, 1), reports.count);
    try testing.expect(reports.decoded >= c.body_len);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}
