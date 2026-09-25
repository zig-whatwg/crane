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
    _ = try scheduler.start(testing.allocator, &request, .{}, Outcome.record, &outcome);
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
    _ = try scheduler.start(testing.allocator, &request_a, .{}, Outcome.record, &outcomes[0]);
    _ = try scheduler.start(testing.allocator, &request_b, .{}, Outcome.record, &outcomes[1]);

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
    const job = try scheduler.start(testing.allocator, &request, .{}, Outcome.record, &outcome);
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
    _ = try scheduler.start(testing.allocator, &request, .{}, Outcome.record, &outcome);

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
            _ = self.scheduler.start(testing.allocator, &next, .{}, Outcome.record, &self.second) catch {};
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
    _ = try scheduler.start(testing.allocator, &first, .{}, Chain.firstDone, &chain);

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
        _ = try scheduler.start(testing.allocator, &request, .{}, Outcome.record, &outcome);
        _ = scheduler.pump();
    }
    // std.testing.allocator fails the test if the transfer outlived deinit.
    try testing.expectEqual(@as(usize, 0), outcome.calls);
}
