//! The network scheduler drives transfers from the event loop without ever
//! waiting for one.
//!
//! `fetch()` used to block the whole thread in `curl_easy_perform` until its
//! response arrived: script, timers and every other fetch waited with it, and
//! a response that never ends hung the process. A transfer on the scheduler
//! is moved along by `pump`, which does as much as the sockets allow and
//! returns - the property every test here measures, alongside the ones the
//! blocking path already had: responses complete, refused connections are
//! reported after their retries, and nothing leaks (`std.testing.allocator`).

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const NetworkScheduler = network.NetworkScheduler;
const NetworkRequest = network.NetworkRequest;
const NetworkResponse = network.NetworkResponse;
const NetworkError = network.NetworkError;
const TestServer = @import("test_server.zig").TestServer;

/// What a completion callback saw.
const Outcome = struct {
    calls: usize = 0,
    status: u16 = 0,
    body_len: usize = 0,
    err: ?NetworkError = null,
    finished_at_ms: i64 = 0,
    queue_wait_ms: f64 = 0,

    fn record(context: ?*anyopaque, result: NetworkError!NetworkResponse) void {
        const self: *Outcome = @ptrCast(@alignCast(context.?));
        self.calls += 1;
        self.finished_at_ms = clock.monotonicMillis();
        var response = result catch |err| {
            self.err = err;
            return;
        };
        defer response.deinit();
        self.status = response.status;
        self.body_len = if (response.body) |b| b.len else 0;
        self.queue_wait_ms = response.queue_wait_ms;
    }
};

fn get(url: []const u8) NetworkRequest {
    return .{ .url = url, .method = "GET", .headers = &.{}, .body = null };
}

/// Pump until `done` holds or `limit_ms` passes, as an event loop would -
/// with a short sleep between turns - and return the longest single pump.
fn pumpUntil(scheduler: *NetworkScheduler, limit_ms: i64, done: *const fn (*anyopaque) bool, ctx: *anyopaque) i64 {
    const deadline = clock.monotonicMillis() + limit_ms;
    var longest: i64 = 0;
    while (!done(ctx) and clock.monotonicMillis() < deadline) {
        const before = clock.monotonicMillis();
        _ = scheduler.pump();
        longest = @max(longest, clock.monotonicMillis() - before);
        clock.sleep(std.time.ns_per_ms);
    }
    return longest;
}

fn outcomeDone(ctx: *anyopaque) bool {
    const outcome: *Outcome = @ptrCast(@alignCast(ctx));
    return outcome.calls > 0;
}

fn urlFor(buf: []u8, server: *TestServer, path: []const u8) ![]const u8 {
    var base_buf: [128]u8 = undefined;
    return std.fmt.bufPrint(buf, "{s}{s}", .{ server.getBaseUrl(&base_buf), path });
}

test "a transfer completes through pump, and no pump waits for the response" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/delay/1"));
    var outcome: Outcome = .{};
    const started_at = clock.monotonicMillis();
    _ = try scheduler.start(testing.allocator, &request, Outcome.record, &outcome);
    try testing.expectEqual(@as(usize, 1), scheduler.inFlight());

    const longest = pumpUntil(&scheduler, 5_000, outcomeDone, &outcome);

    try testing.expectEqual(@as(usize, 1), outcome.calls);
    try testing.expectEqual(@as(?NetworkError, null), outcome.err);
    try testing.expectEqual(@as(u16, 200), outcome.status);
    try testing.expect(outcome.body_len > 0);
    // The server held the response for a second; no single pump did.
    try testing.expect(outcome.finished_at_ms - started_at >= 900);
    try testing.expect(longest < 250);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
}

test "a transfer is under way from start, not from the first pump" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/delay/1"));
    var outcome: Outcome = .{};
    const started_at = clock.monotonicMillis();
    _ = try scheduler.start(testing.allocator, &request, Outcome.record, &outcome);

    // Script runs for longer than the server takes, and nothing pumps: the
    // request must already have gone out, as it would from a browser's
    // network thread, or the second only starts counting now.
    clock.sleep(1_200 * std.time.ns_per_ms);
    _ = pumpUntil(&scheduler, 5_000, outcomeDone, &outcome);

    try testing.expectEqual(@as(u16, 200), outcome.status);
    try testing.expect(outcome.finished_at_ms - started_at < 1_900);
}

test "transfers to two servers are in flight at once" {
    try network.globalInit();
    defer network.globalCleanup();
    // The test server answers one connection at a time, so concurrency needs
    // two of them.
    const a = try TestServer.start(testing.allocator);
    defer a.stop();
    const b = try TestServer.start(testing.allocator);
    defer b.stop();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_a: [256]u8 = undefined;
    var url_b: [256]u8 = undefined;
    const request_a = get(try urlFor(&url_a, a, "/delay/1"));
    const request_b = get(try urlFor(&url_b, b, "/delay/1"));
    var outcomes = [2]Outcome{ .{}, .{} };
    const started_at = clock.monotonicMillis();
    _ = try scheduler.start(testing.allocator, &request_a, Outcome.record, &outcomes[0]);
    _ = try scheduler.start(testing.allocator, &request_b, Outcome.record, &outcomes[1]);

    const Both = struct {
        fn done(ctx: *anyopaque) bool {
            const o: *[2]Outcome = @ptrCast(@alignCast(ctx));
            return o[0].calls > 0 and o[1].calls > 0;
        }
    };
    _ = pumpUntil(&scheduler, 5_000, Both.done, &outcomes);

    try testing.expectEqual(@as(u16, 200), outcomes[0].status);
    try testing.expectEqual(@as(u16, 200), outcomes[1].status);
    // One after the other would be two seconds.
    const elapsed = @max(outcomes[0].finished_at_ms, outcomes[1].finished_at_ms) - started_at;
    try testing.expect(elapsed < 1_800);
}

test "a cancelled transfer never completes, and leaves nothing behind" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/delay/1"));
    var outcome: Outcome = .{};
    const job = try scheduler.start(testing.allocator, &request, Outcome.record, &outcome);
    // Let it reach the server first.
    _ = scheduler.pump();
    scheduler.cancel(job);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());

    const deadline = clock.monotonicMillis() + 1_500;
    while (clock.monotonicMillis() < deadline) {
        _ = scheduler.pump();
        clock.sleep(5 * std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 0), outcome.calls);
}

test "a refused connection is reported once its retries are spent, without a pump waiting on them" {
    try network.globalInit();
    defer network.globalCleanup();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    // Port 9 (discard) on loopback: refused at once, with no DNS lookup and no
    // external network.
    const request = get("http://127.0.0.1:9/");
    var outcome: Outcome = .{};
    const started_at = clock.monotonicMillis();
    _ = try scheduler.start(testing.allocator, &request, Outcome.record, &outcome);

    const longest = pumpUntil(&scheduler, 5_000, outcomeDone, &outcome);

    try testing.expectEqual(@as(usize, 1), outcome.calls);
    try testing.expectEqual(@as(?NetworkError, NetworkError.ConnectionRefused), outcome.err);
    // Three attempts, 100ms and 200ms apart, as a blocking send makes them -
    // but the backoff is waited out between pumps, not inside one.
    try testing.expect(outcome.finished_at_ms - started_at >= 280);
    try testing.expect(longest < 250);
}

test "a completion callback may start the next transfer" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();

    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    // What following a redirect looks like: the first response's callback
    // starts the second transfer from inside `pump`.
    const Chain = struct {
        scheduler: *NetworkScheduler,
        second_url: []const u8,
        first: Outcome = .{},
        second: Outcome = .{},

        fn firstDone(context: ?*anyopaque, result: NetworkError!NetworkResponse) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            Outcome.record(&self.first, result);
            const next = get(self.second_url);
            _ = self.scheduler.start(testing.allocator, &next, Outcome.record, &self.second) catch {};
        }

        fn done(ctx: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.second.calls > 0;
        }
    };

    var first_buf: [256]u8 = undefined;
    var second_buf: [256]u8 = undefined;
    var chain: Chain = .{ .scheduler = &scheduler, .second_url = try urlFor(&second_buf, server, "/get") };
    const first = get(try urlFor(&first_buf, server, "/status/204"));
    _ = try scheduler.start(testing.allocator, &first, Chain.firstDone, &chain);

    _ = pumpUntil(&scheduler, 5_000, Chain.done, &chain);

    try testing.expectEqual(@as(u16, 204), chain.first.status);
    try testing.expectEqual(@as(u16, 200), chain.second.status);
}

test "deinit cancels what is still in flight" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/delay/1"));
    var outcome: Outcome = .{};
    {
        var scheduler = NetworkScheduler.init(testing.allocator);
        defer scheduler.deinit();
        _ = try scheduler.start(testing.allocator, &request, Outcome.record, &outcome);
        _ = scheduler.pump();
    }
    // std.testing.allocator fails the test if the transfer outlived deinit.
    try testing.expectEqual(@as(usize, 0), outcome.calls);
}

fn allDone(ctx: *anyopaque) bool {
    const outcomes: *[]Outcome = @ptrCast(@alignCast(ctx));
    for (outcomes.*) |o| if (o.calls == 0) return false;
    return true;
}

/// Pump both schedulers - two agents of one Browser - until every outcome is in.
fn pumpBothUntil(a: *NetworkScheduler, b: *NetworkScheduler, limit_ms: i64, outcomes: []Outcome) void {
    const deadline = clock.monotonicMillis() + limit_ms;
    var all = outcomes;
    while (!allDone(@ptrCast(&all)) and clock.monotonicMillis() < deadline) {
        _ = a.pump();
        _ = b.pump();
        clock.sleep(std.time.ns_per_ms);
    }
}

fn expectAllOk(outcomes: []const Outcome) !void {
    for (outcomes) |o| {
        try testing.expectEqual(@as(usize, 1), o.calls);
        try testing.expectEqual(@as(?NetworkError, null), o.err);
        try testing.expectEqual(@as(u16, 200), o.status);
    }
}

test "a Browser opens six connections to a destination; more transfers wait their turn and all complete" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var context = network.NetworkContext.init(testing.allocator);
    defer context.deinit();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    var request = get(try urlFor(&url_buf, server, "/get"));
    request.network = &context;
    var outcomes: [8]Outcome = @splat(.{});
    for (&outcomes) |*outcome| _ = try scheduler.start(testing.allocator, &request, Outcome.record, outcome);
    // Six under way, two waiting for a slot (every browser's six,
    // network_context.max_connections_per_host); all eight are in flight.
    try testing.expectEqual(@as(usize, 8), scheduler.inFlight());
    try testing.expectEqual(@as(usize, 2), scheduler.waitingForSlot());

    var all: []Outcome = &outcomes;
    _ = pumpUntil(&scheduler, 10_000, allDone, @ptrCast(&all));
    try expectAllOk(&outcomes);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
    // The six that started at once waited for nothing; the two that waited
    // carry how long, which Resource Timing places before domainLookupStart.
    var waited: usize = 0;
    for (outcomes[0..6]) |o| try testing.expectEqual(@as(f64, 0), o.queue_wait_ms);
    for (outcomes[6..]) |o| if (o.queue_wait_ms > 0) {
        waited += 1;
    };
    try testing.expectEqual(@as(usize, 2), waited);
    // Every slot was given back: six more start at once.
    var again: [6]Outcome = @splat(.{});
    for (&again) |*outcome| _ = try scheduler.start(testing.allocator, &request, Outcome.record, outcome);
    try testing.expectEqual(@as(usize, 0), scheduler.waitingForSlot());
    var rest: []Outcome = &again;
    _ = pumpUntil(&scheduler, 10_000, allDone, @ptrCast(&rest));
    try expectAllOk(&again);
}

test "connection slots are the Browser's: two agents' schedulers share a destination's six" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var context = network.NetworkContext.init(testing.allocator);
    defer context.deinit();
    var window = NetworkScheduler.init(testing.allocator);
    defer window.deinit();
    var worker = NetworkScheduler.init(testing.allocator);
    defer worker.deinit();

    var url_buf: [256]u8 = undefined;
    var request = get(try urlFor(&url_buf, server, "/get"));
    request.network = &context;
    var outcomes: [8]Outcome = @splat(.{});
    for (outcomes[0..4]) |*outcome| _ = try window.start(testing.allocator, &request, Outcome.record, outcome);
    for (outcomes[4..]) |*outcome| _ = try worker.start(testing.allocator, &request, Outcome.record, outcome);
    try testing.expectEqual(@as(usize, 0), window.waitingForSlot());
    try testing.expectEqual(@as(usize, 2), worker.waitingForSlot());
    // A slot the window's transfers give back starts the worker's.
    pumpBothUntil(&window, &worker, 10_000, &outcomes);
    try expectAllOk(&outcomes);
    try testing.expectEqual(@as(usize, 0), worker.inFlight());
}

test "a cancelled transfer gives its slot to the next, and a waiting one cancelled holds none" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var context = network.NetworkContext.init(testing.allocator);
    defer context.deinit();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    var request = get(try urlFor(&url_buf, server, "/get"));
    request.network = &context;
    var outcomes: [8]Outcome = @splat(.{});
    var jobs: [8]*NetworkScheduler.Job = undefined;
    for (&outcomes, &jobs) |*outcome, *job| job.* = try scheduler.start(testing.allocator, &request, Outcome.record, outcome);
    try testing.expectEqual(@as(usize, 2), scheduler.waitingForSlot());
    // A waiting one cancelled: still one waiting, no slot freed.
    scheduler.cancel(jobs[7]);
    try testing.expectEqual(@as(usize, 1), scheduler.waitingForSlot());
    // A running one cancelled: its slot goes to the one still waiting, at
    // the next pump.
    scheduler.cancel(jobs[0]);
    _ = scheduler.pump();
    try testing.expectEqual(@as(usize, 0), scheduler.waitingForSlot());
    var live: []Outcome = outcomes[1..7];
    _ = pumpUntil(&scheduler, 10_000, allDone, @ptrCast(&live));
    try expectAllOk(outcomes[1..7]);
    try testing.expectEqual(@as(usize, 0), outcomes[0].calls);
    try testing.expectEqual(@as(usize, 0), outcomes[7].calls);
}

test "a destination that speaks HTTP/2 is not limited to six transfers" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var context = network.NetworkContext.init(testing.allocator);
    defer context.deinit();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    var request = get(try urlFor(&url_buf, server, "/get"));
    request.network = &context;
    var destination_buf: [network.network_context.max_host_key]u8 = undefined;
    // As a head over HTTP/2 records it: its requests share one connection.
    try context.noteMultiplexed(network.network_context.destinationOf(&destination_buf, request.url).?);
    var outcomes: [8]Outcome = @splat(.{});
    for (&outcomes) |*outcome| _ = try scheduler.start(testing.allocator, &request, Outcome.record, outcome);
    try testing.expectEqual(@as(usize, 0), scheduler.waitingForSlot());
    var all: []Outcome = &outcomes;
    _ = pumpUntil(&scheduler, 10_000, allDone, @ptrCast(&all));
    try expectAllOk(&outcomes);
}

/// What a streamed transfer's client heard, in order.
const StreamRecord = struct {
    status: u16 = 0,
    content_type_seen: bool = false,
    /// The head's word on its connection: one the transfer reused.
    connection_reused: ?bool = null,
    head_at_ms: i64 = 0,
    chunks: usize = 0,
    bytes: std.ArrayListUnmanaged(u8) = .empty,
    first_data_at_ms: i64 = 0,
    ended: bool = false,
    end_error: ?NetworkError = null,
    end_at_ms: i64 = 0,
    order_ok: bool = true,

    fn client(self: *StreamRecord) network.scheduler.StreamClient {
        return .{ .context = self, .head = head, .data = data, .end = end };
    }

    fn head(context: ?*anyopaque, response: NetworkResponse) void {
        const self: *StreamRecord = @ptrCast(@alignCast(context.?));
        var r = response;
        defer r.deinit();
        if (self.ended or self.chunks > 0) self.order_ok = false;
        self.status = r.status;
        self.connection_reused = r.connection_reused;
        self.head_at_ms = clock.monotonicMillis();
        for (r.headers) |h| {
            if (std.ascii.eqlIgnoreCase(h.name, "content-type")) self.content_type_seen = true;
        }
        if (r.body != null) self.order_ok = false;
    }

    fn data(context: ?*anyopaque, bytes: []const u8) void {
        const self: *StreamRecord = @ptrCast(@alignCast(context.?));
        if (self.status == 0 or self.ended) self.order_ok = false;
        if (self.chunks == 0) self.first_data_at_ms = clock.monotonicMillis();
        self.chunks += 1;
        self.bytes.appendSlice(testing.allocator, bytes) catch {};
    }

    fn end(context: ?*anyopaque, result: NetworkError!void) void {
        const self: *StreamRecord = @ptrCast(@alignCast(context.?));
        if (self.ended) self.order_ok = false;
        self.ended = true;
        self.end_at_ms = clock.monotonicMillis();
        result catch |err| {
            self.end_error = err;
        };
    }

    fn deinit(self: *StreamRecord) void {
        self.bytes.deinit(testing.allocator);
    }

    fn isEnded(ctx: *anyopaque) bool {
        const self: *StreamRecord = @ptrCast(@alignCast(ctx));
        return self.ended;
    }
};

test "a streamed transfer hands on its headers before its body, and its body as it arrives" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/trickle/10"));
    var record: StreamRecord = .{};
    defer record.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &request, record.client());

    const longest = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &record);

    try testing.expect(record.order_ok);
    try testing.expectEqual(@as(u16, 200), record.status);
    try testing.expect(record.content_type_seen);
    try testing.expectEqual(@as(?NetworkError, null), record.end_error);
    // Ten chunks, 100ms apart: the headers and the first piece arrive long
    // before the end, and the body comes in more than one piece.
    try testing.expectEqual(@as(usize, 60), record.bytes.items.len);
    try testing.expect(record.chunks >= 3);
    try testing.expect(record.end_at_ms - record.head_at_ms >= 700);
    try testing.expect(record.end_at_ms - record.first_data_at_ms >= 700);
    try testing.expect(longest < 250);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
}

test "a streamed transfer's head says whether its connection was reused" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/keep-alive"));
    // The first transfer opens the connection; the second, after the first
    // has ended, finds it idle and reuses it. A navigation is a streamed
    // transfer, and Resource Timing reads a reused connection's times from
    // this word (HTTP-network fetch step 8.2): a head that always said
    // "fresh" made navigation-timing/secure-connection-start-reuse.https.html
    // compare two clock readings (16 of 50 runs failed).
    var first: StreamRecord = .{};
    defer first.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &request, first.client());
    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &first);
    try testing.expectEqual(@as(?NetworkError, null), first.end_error);
    try testing.expectEqualStrings("ok", first.bytes.items);
    try testing.expectEqual(@as(?bool, false), first.connection_reused);

    var second: StreamRecord = .{};
    defer second.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &request, second.client());
    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &second);
    try testing.expectEqual(@as(?NetworkError, null), second.end_error);
    try testing.expectEqualStrings("ok", second.bytes.items);
    try testing.expectEqual(@as(?bool, true), second.connection_reused);
}

test "a connection is not reused after a bodyless response that announced a body" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var first_buf: [256]u8 = undefined;
    const first_request = get(try urlFor(&first_buf, server, "/not-modified-with-body"));
    var second_buf: [256]u8 = undefined;
    const second_request = get(try urlFor(&second_buf, server, "/keep-alive"));
    // A 304 has no body, whatever its Content-Length says - and the server
    // sends one anyway, later. Reused, the connection would hand the next
    // request "TESTHTTP/1.1 200 OK": curl's "Invalid status line"
    // (xhr/send-redirect.htm, 12 of 72 runs under 8 runner processes, after
    // the per-destination cap made reuse more frequent).
    var first: StreamRecord = .{};
    defer first.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &first_request, first.client());
    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &first);
    try testing.expectEqual(@as(?NetworkError, null), first.end_error);
    try testing.expectEqual(@as(u16, 304), first.status);

    var second: StreamRecord = .{};
    defer second.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &second_request, second.client());
    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &second);
    try testing.expectEqual(@as(?NetworkError, null), second.end_error);
    try testing.expectEqual(@as(u16, 200), second.status);
    try testing.expectEqualStrings("ok", second.bytes.items);
    try testing.expectEqual(@as(?bool, false), second.connection_reused);
}

test "a streamed transfer that fails after its headers ends in error" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/bad-chunk"));
    var record: StreamRecord = .{};
    defer record.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &request, record.client());

    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &record);

    try testing.expect(record.order_ok);
    try testing.expectEqual(@as(u16, 200), record.status);
    try testing.expectEqualStrings("chunk\n", record.bytes.items);
    try testing.expect(record.end_error != null);
}

test "a streamed transfer that never connects ends with no headers" {
    try network.globalInit();
    defer network.globalCleanup();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    const request = get("http://127.0.0.1:9/");
    var record: StreamRecord = .{};
    defer record.deinit();
    _ = try scheduler.startStreaming(testing.allocator, &request, record.client());

    _ = pumpUntil(&scheduler, 5_000, StreamRecord.isEnded, &record);

    try testing.expectEqual(@as(u16, 0), record.status);
    try testing.expectEqual(@as(?NetworkError, NetworkError.ConnectionRefused), record.end_error);
}

test "a streamed transfer cancelled from its own head callback hears nothing more" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    const Canceller = struct {
        scheduler: *NetworkScheduler,
        job: ?*NetworkScheduler.Job = null,
        heads: usize = 0,
        others: usize = 0,

        fn head(context: ?*anyopaque, response: NetworkResponse) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            var r = response;
            r.deinit();
            self.heads += 1;
            self.scheduler.cancel(self.job.?);
        }
        fn data(context: ?*anyopaque, _: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.others += 1;
        }
        fn end(context: ?*anyopaque, _: NetworkError!void) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            self.others += 1;
        }
        fn gotHead(ctx: *anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            return self.heads > 0;
        }
    };

    var url_buf: [256]u8 = undefined;
    const request = get(try urlFor(&url_buf, server, "/trickle/5"));
    var canceller: Canceller = .{ .scheduler = &scheduler };
    canceller.job = try scheduler.startStreaming(testing.allocator, &request, .{
        .context = &canceller,
        .head = Canceller.head,
        .data = Canceller.data,
        .end = Canceller.end,
    });
    _ = pumpUntil(&scheduler, 5_000, Canceller.gotHead, &canceller);
    const deadline = clock.monotonicMillis() + 800;
    while (clock.monotonicMillis() < deadline) {
        _ = scheduler.pump();
        clock.sleep(5 * std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 1), canceller.heads);
    try testing.expectEqual(@as(usize, 0), canceller.others);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
}
