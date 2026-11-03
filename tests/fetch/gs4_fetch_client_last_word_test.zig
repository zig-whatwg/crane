//! An AsyncFetch's client hears `gone` or `finished` LAST: nothing - no
//! `alive`, no `done` - after either, and nothing at all after the client
//! terminates the fetch itself. A navigation's fetch client keeps a ticket
//! (its Browser's navigations and its ID; HTMLIFrameElement, lane gstate4)
//! that `gone` and `finished` free, and that whoever terminates the fetch
//! frees: these are the calls it relies on being last.
const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const AsyncFetch = fetch.algorithms.AsyncFetch;
const AgentFetches = fetch.algorithms.AgentFetches;
const InternalRequest = fetch.internal.InternalRequest;
const TestServer = @import("test_server.zig").TestServer;

/// A client that journals what it hears, and every call after its last word.
const Journal = struct {
    alive: bool = true,
    done_calls: usize = 0,
    alive_calls: usize = 0,
    gone_calls: usize = 0,
    finished_calls: usize = 0,
    /// Calls after `gone` or `finished`.
    after_last_word: usize = 0,
    over: bool = false,

    fn client(self: *Journal) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = isAlive, .gone = gone, .finished = finished };
    }

    fn heard(self: *Journal) void {
        if (self.over) self.after_last_word += 1;
    }

    fn done(context: *anyopaque, result: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Journal = @ptrCast(@alignCast(context));
        self.heard();
        self.done_calls += 1;
        // Nobody reads the body: the fetch is over once the pipe goes.
        var r = result catch return;
        r.deinit();
    }

    fn isAlive(context: *anyopaque) bool {
        const self: *Journal = @ptrCast(@alignCast(context));
        self.heard();
        self.alive_calls += 1;
        return self.alive;
    }

    fn gone(context: *anyopaque) void {
        const self: *Journal = @ptrCast(@alignCast(context));
        self.heard();
        self.gone_calls += 1;
        self.over = true;
    }

    fn finished(context: *anyopaque) void {
        const self: *Journal = @ptrCast(@alignCast(context));
        self.heard();
        self.finished_calls += 1;
        self.over = true;
    }
};

fn requestFor(server: *TestServer, path: []const u8) !*InternalRequest {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ server.getBaseUrl(&base_buf), path });
    return InternalRequest.init(testing.allocator, url);
}

/// Turn the fetches' loop for `ms` milliseconds.
fn turnFor(fetches: *AgentFetches, ms: i64) void {
    const deadline = clock.monotonicMillis() + ms;
    while (clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(2 * std.time.ns_per_ms);
    }
}

test "after done, finished is the client's last word" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();

    var journal: Journal = .{};
    _ = try AsyncFetch.startStreaming(testing.allocator, try requestFor(server, "/trickle/5"), .{}, &fetches, journal.client());
    const deadline = clock.monotonicMillis() + 5_000;
    while (journal.finished_calls == 0 and clock.monotonicMillis() < deadline) {
        _ = fetches.pump();
        clock.sleep(std.time.ns_per_ms);
    }
    turnFor(&fetches, 100);
    try testing.expectEqual(@as(usize, 1), journal.done_calls);
    try testing.expectEqual(@as(usize, 1), journal.finished_calls);
    try testing.expectEqual(@as(usize, 0), journal.gone_calls);
    try testing.expectEqual(@as(usize, 0), journal.after_last_word);
    try testing.expectEqual(@as(usize, 0), fetches.inFlight());
}

test "a client that is gone hears gone once, and nothing after" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();

    var journal: Journal = .{};
    _ = try AsyncFetch.startStreaming(testing.allocator, try requestFor(server, "/delay/1"), .{}, &fetches, journal.client());
    _ = fetches.pump();
    journal.alive = false;
    turnFor(&fetches, 200);
    try testing.expectEqual(@as(usize, 1), journal.gone_calls);
    try testing.expectEqual(@as(usize, 0), journal.finished_calls);
    try testing.expectEqual(@as(usize, 0), journal.done_calls);
    try testing.expectEqual(@as(usize, 0), journal.after_last_word);
}

test "a fetch its client terminates calls the client nothing more" {
    try network.globalInit();
    defer network.globalCleanup();
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    var fetches = AgentFetches.init(testing.allocator);
    defer fetches.deinit();

    var journal: Journal = .{};
    const f = try AsyncFetch.startStreaming(testing.allocator, try requestFor(server, "/delay/1"), .{}, &fetches, journal.client());
    _ = fetches.pump();
    const heard = journal.done_calls + journal.alive_calls + journal.gone_calls + journal.finished_calls;
    f.terminate();
    turnFor(&fetches, 300);
    try testing.expectEqual(heard, journal.done_calls + journal.alive_calls + journal.gone_calls + journal.finished_calls);
}
