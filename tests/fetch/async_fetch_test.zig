//! Fetch on the event loop: `AsyncFetch` runs the fetch algorithm with its
//! network requests on the scheduler, and delivers its outcome from `pump`.
//!
//! `fetch()`, the method, used to run the whole algorithm - redirects
//! included - inside the call, blocked in `curl_easy_perform`. These pin the
//! event-loop version against the local test server: the outcome arrives from
//! `pump` and no pump waits for the network, redirects are followed across
//! turns, a fetch that needs no network is still delivered by `pump` rather
//! than from inside `start`, and a fetch whose client has gone away is ended
//! with nothing leaked (`std.testing.allocator`).

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const algorithms = fetch.algorithms;
const AsyncFetch = algorithms.AsyncFetch;
const async_fetch = algorithms.async_fetch;
const NetworkScheduler = network.NetworkScheduler;
const InternalRequest = fetch.internal.InternalRequest;
const TestServer = @import("test_server.zig").TestServer;

/// A client that records what it heard.
const Recorder = struct {
    alive: bool = true,
    done_calls: usize = 0,
    gone_calls: usize = 0,
    failed: bool = false,
    network_error: bool = false,
    status: u16 = 0,
    url_count: usize = 0,
    final_url: [256]u8 = undefined,
    final_url_len: usize = 0,

    fn client(self: *Recorder) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = isAlive, .gone = gone };
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
        self.url_count = r.response.url_list.items.len;
        if (self.url_count > 0) {
            const last = r.response.url_list.items[self.url_count - 1];
            const n = @min(last.len, self.final_url.len);
            @memcpy(self.final_url[0..n], last[0..n]);
            self.final_url_len = n;
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

    fn finalUrl(self: *const Recorder) []const u8 {
        return self.final_url[0..self.final_url_len];
    }
};

/// Turn the event loop's network step until `recorder` hears, or `limit_ms`
/// passes. Returns the longest single turn.
fn turnUntilDone(scheduler: *NetworkScheduler, recorder: *const Recorder, limit_ms: i64) i64 {
    const deadline = clock.monotonicMillis() + limit_ms;
    var longest: i64 = 0;
    while (recorder.done_calls == 0 and recorder.gone_calls == 0 and clock.monotonicMillis() < deadline) {
        const before = clock.monotonicMillis();
        _ = async_fetch.pumpWith(scheduler);
        longest = @max(longest, clock.monotonicMillis() - before);
        clock.sleep(std.time.ns_per_ms);
    }
    return longest;
}

fn requestFor(server: *TestServer, path: []const u8) !*InternalRequest {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ server.getBaseUrl(&base_buf), path });
    return InternalRequest.init(testing.allocator, url);
}

test "a fetch completes from the event loop's network step, which never waits for it" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var recorder: Recorder = .{};
    const started_at = clock.monotonicMillis();
    _ = try AsyncFetch.start(testing.allocator, try requestFor(server, "/delay/1"), .{}, &scheduler, recorder.client());
    try testing.expectEqual(@as(usize, 1), async_fetch.inFlight());

    const longest = turnUntilDone(&scheduler, &recorder, 5_000);

    try testing.expectEqual(@as(usize, 1), recorder.done_calls);
    try testing.expect(!recorder.failed);
    try testing.expectEqual(@as(u16, 200), recorder.status);
    try testing.expect(clock.monotonicMillis() - started_at >= 900);
    try testing.expect(longest < 250);
    try testing.expectEqual(@as(usize, 0), async_fetch.inFlight());
}

test "a redirect is followed on a later turn, and the response reports both hops" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var recorder: Recorder = .{};
    _ = try AsyncFetch.start(testing.allocator, try requestFor(server, "/redirect-abs"), .{}, &scheduler, recorder.client());
    _ = turnUntilDone(&scheduler, &recorder, 5_000);

    try testing.expectEqual(@as(usize, 1), recorder.done_calls);
    try testing.expectEqual(@as(u16, 200), recorder.status);
    try testing.expectEqual(@as(usize, 2), recorder.url_count);
    try testing.expect(std.mem.endsWith(u8, recorder.finalUrl(), "/get"));
}

test "a fetch that needs no network is still delivered by the network step, not by start" {
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var recorder: Recorder = .{};
    const request = try InternalRequest.init(testing.allocator, "data:text/plain,hello");
    _ = try AsyncFetch.start(testing.allocator, request, .{}, &scheduler, recorder.client());
    // The client's code runs at the top of an event loop step, never inside
    // the call that started the fetch.
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);

    _ = async_fetch.pumpWith(&scheduler);
    try testing.expectEqual(@as(usize, 1), recorder.done_calls);
    try testing.expectEqual(@as(u16, 200), recorder.status);
}

test "a refused connection ends the fetch with a network error" {
    try network.globalInit();
    defer network.globalCleanup();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    // Nothing listens there, and it is not one of Fetch's bad ports, so the
    // request does reach the network.
    var recorder: Recorder = .{};
    const request = try InternalRequest.init(testing.allocator, "http://127.0.0.1:59999/refused");
    _ = try AsyncFetch.start(testing.allocator, request, .{}, &scheduler, recorder.client());
    _ = turnUntilDone(&scheduler, &recorder, 5_000);

    try testing.expectEqual(@as(usize, 1), recorder.done_calls);
    try testing.expect(!recorder.failed);
    try testing.expect(recorder.network_error);
}

test "a fetch whose client is gone is ended, its transfer with it, and the client told" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var recorder: Recorder = .{};
    _ = try AsyncFetch.start(testing.allocator, try requestFor(server, "/delay/1"), .{}, &scheduler, recorder.client());
    _ = async_fetch.pumpWith(&scheduler);
    try testing.expectEqual(@as(usize, 1), scheduler.inFlight());

    // The page went away.
    recorder.alive = false;
    _ = async_fetch.pumpWith(&scheduler);

    try testing.expectEqual(@as(usize, 1), recorder.gone_calls);
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
    try testing.expectEqual(@as(usize, 0), async_fetch.inFlight());
}

test "terminate ends a fetch with no word to its client" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var scheduler = NetworkScheduler.init(testing.allocator);
    defer scheduler.deinit();

    var recorder: Recorder = .{};
    const f = try AsyncFetch.start(testing.allocator, try requestFor(server, "/delay/1"), .{}, &scheduler, recorder.client());
    _ = async_fetch.pumpWith(&scheduler);
    f.terminate();

    const deadline = clock.monotonicMillis() + 1_500;
    while (clock.monotonicMillis() < deadline) {
        _ = async_fetch.pumpWith(&scheduler);
        clock.sleep(5 * std.time.ns_per_ms);
    }
    try testing.expectEqual(@as(usize, 0), recorder.done_calls);
    try testing.expectEqual(@as(usize, 0), recorder.gone_calls);
    try testing.expectEqual(@as(usize, 0), scheduler.inFlight());
}
