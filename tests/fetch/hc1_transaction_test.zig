//! HTTP-network-or-cache fetch's use of the HTTP cache (Fetch 4.6 steps
//! 24-26 and 11.1-11.5), driven with requests and responses as fetch makes
//! them (lane httpcache1): what the cache answers, what it sends the
//! network, what a 304 does, what is stored and when.
const std = @import("std");
const fetch = @import("fetch");
const cache = fetch.cache;
const Transaction = cache.Transaction;
const HeaderView = cache.HeaderView;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const NetworkContext = fetch.network.NetworkContext;
const NetHeader = fetch.network.NetworkRequest.Header;
const body_pipe = fetch.internal.body_pipe;

const t0: i64 = 1_800_000_000;

const Fixture = struct {
    network: NetworkContext,

    fn init(config: NetworkContext.HttpCacheConfig) !Fixture {
        var network = NetworkContext.init(std.testing.allocator);
        errdefer network.deinit();
        try network.configure(.{ .http_cache = config });
        return .{ .network = network };
    }

    fn deinit(self: *Fixture) void {
        self.network.deinit();
    }

    fn request(self: *Fixture, url: []const u8) !*InternalRequest {
        const r = try InternalRequest.init(std.testing.allocator, url);
        r.network = &self.network;
        r.network_partition_key = try std.testing.allocator.dupe(u8, "http://top.test");
        return r;
    }

    fn store(self: *Fixture) *fetch.cache.HttpCache {
        return self.network.http_cache.?;
    }
};

const Field = struct { []const u8, []const u8 };

fn response(status: u16, fields: []const Field, body: []const u8) !*InternalResponse {
    const r = try InternalResponse.init(std.testing.allocator);
    errdefer r.deinit();
    r.status = status;
    for (fields) |f| try r.header_list.append(f[0], f[1]);
    r.body = try fetch.internal.Body.fromBytes(std.testing.allocator, body);
    return r;
}

fn viewOf(request: *const InternalRequest) HeaderView {
    return .{ .author = request.header_list.iterator() };
}

/// begin, expecting the network; returns the transaction.
fn expectNetwork(begun: Transaction.Begin) !Transaction.Network {
    return switch (begun) {
        .network => |n| n,
        else => error.TestExpectedNetwork,
    };
}

/// One whole exchange: begin (expecting the network), then the network's
/// `answer` (taken). Returns the response fetch goes on with.
fn exchange(request: *InternalRequest, answer: *InternalResponse, now: i64) !*InternalResponse {
    var network = expectNetwork(try Transaction.begin(std.testing.allocator, request, viewOf(request), now)) catch |err| {
        answer.deinit();
        return err;
    };
    defer network.transaction.deinit();
    return network.transaction.afterNetwork(std.testing.allocator, request, viewOf(request), answer, now);
}

test "hc1 transaction: a fresh stored response answers without the network, cache state local" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const first = try fx.request("http://a.test/x#frag");
    defer first.deinit();
    const answered = try exchange(first, try response(200, &.{ .{ "Cache-Control", "max-age=60" }, .{ "Content-Type", "text/plain" } }, "hello"), t0);
    answered.deinit();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());

    const second = try fx.request("http://a.test/x");
    defer second.deinit();
    const begun = try Transaction.begin(std.testing.allocator, second, viewOf(second), t0 + 30);
    const hit = switch (begun) {
        .response => |r| r,
        else => return error.TestExpectedHit,
    };
    defer hit.deinit();
    try std.testing.expectEqual(fetch.internal.CacheState.local, hit.cache_state);
    try std.testing.expectEqual(@as(u16, 200), hit.status);
    try std.testing.expectEqualStrings("hello", hit.body.?.getBytes());
    try std.testing.expectEqualStrings("text/plain", hit.header_list.getFirstValue("Content-Type").?);
    // The body info stored alongside it (11.5.2's note).
    try std.testing.expectEqual(@as(u64, 5), hit.body_info.encoded_size);
    try std.testing.expectEqual(@as(u64, 5), hit.body_info.decoded_size);
    try std.testing.expectEqualStrings("http://a.test/x", hit.url().?);
}

test "hc1 transaction: a stale response is revalidated, and a 304 updates it - cache state validated" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const first = try fx.request("http://a.test/v");
    defer first.deinit();
    (try exchange(first, try response(200, &.{ .{ "ETag", "\"e1\"" }, .{ "Last-Modified", "Sun, 06 Nov 1994 08:49:37 GMT" }, .{ "Cache-Control", "max-age=10" }, .{ "X-Old", "1" } }, "body"), t0)).deinit();

    const second = try fx.request("http://a.test/v");
    defer second.deinit();
    var network = try expectNetwork(try Transaction.begin(std.testing.allocator, second, viewOf(second), t0 + 100));
    defer network.transaction.deinit();
    // 26.2.2.2: both validators of the stored response.
    try std.testing.expectEqualStrings("\"e1\"", network.if_none_match.?);
    try std.testing.expectEqualStrings("Sun, 06 Nov 1994 08:49:37 GMT", network.if_modified_since.?);
    const not_modified = try response(304, &.{ .{ "ETag", "\"e1\"" }, .{ "X-Old", "2" }, .{ "Cache-Control", "max-age=600" } }, "");
    const validated = try network.transaction.afterNetwork(std.testing.allocator, second, viewOf(second), not_modified, t0 + 101);
    defer validated.deinit();
    try std.testing.expectEqual(fetch.internal.CacheState.validated, validated.cache_state);
    try std.testing.expectEqual(@as(u16, 200), validated.status);
    try std.testing.expectEqualStrings("body", validated.body.?.getBytes());
    try std.testing.expectEqualStrings("2", validated.header_list.getFirstValue("X-Old").?);
    try std.testing.expectEqual(@as(u64, 4), validated.body_info.encoded_size);

    // "This updates the stored response in cache as well": now fresh.
    const third = try fx.request("http://a.test/v");
    defer third.deinit();
    switch (try Transaction.begin(std.testing.allocator, third, viewOf(third), t0 + 200)) {
        .response => |r| {
            defer r.deinit();
            try std.testing.expectEqualStrings("2", r.header_list.getFirstValue("X-Old").?);
        },
        else => return error.TestExpectedHit,
    }
}

test "hc1 transaction: a 304 without validators updates; one whose ETag disagrees does not" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const url = "http://a.test/c";
    const first = try fx.request(url);
    defer first.deinit();
    (try exchange(first, try response(200, &.{ .{ "ETag", "abcdef" }, .{ "Cache-Control", "private, max-age=3, must-revalidate" }, .{ "A", "1" } }, "Success"), t0)).deinit();
    {
        // cors/304.htm's server: the 304 carries no ETag.
        const again = try fx.request(url);
        defer again.deinit();
        var n = try expectNetwork(try Transaction.begin(std.testing.allocator, again, viewOf(again), t0 + 5));
        defer n.transaction.deinit();
        const r = try n.transaction.afterNetwork(std.testing.allocator, again, viewOf(again), try response(304, &.{.{ "A", "2" }}, ""), t0 + 5);
        defer r.deinit();
        try std.testing.expectEqual(@as(u16, 200), r.status);
        try std.testing.expectEqualStrings("Success", r.body.?.getBytes());
        try std.testing.expectEqualStrings("2", r.header_list.getFirstValue("A").?);
    }
    {
        const again = try fx.request(url);
        defer again.deinit();
        var n = try expectNetwork(try Transaction.begin(std.testing.allocator, again, viewOf(again), t0 + 20));
        defer n.transaction.deinit();
        const r = try n.transaction.afterNetwork(std.testing.allocator, again, viewOf(again), try response(304, &.{.{ "ETag", "other" }}, ""), t0 + 20);
        defer r.deinit();
        // Handed on as it is, and the stored response is gone.
        try std.testing.expectEqual(@as(u16, 304), r.status);
        try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
    }
}

test "hc1 transaction: force-cache and only-if-cached use a stale response; only-if-cached with none is a network error" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const first = try fx.request("http://a.test/s");
    defer first.deinit();
    (try exchange(first, try response(200, &.{ .{ "ETag", "\"s\"" }, .{ "Expires", "Thu, 01 Jan 1970 00:00:00 GMT" } }, "stale"), t0)).deinit();
    for ([_]fetch.internal.CacheMode{ .force_cache, .only_if_cached }) |mode| {
        const r = try fx.request("http://a.test/s");
        defer r.deinit();
        r.cache_mode = mode;
        switch (try Transaction.begin(std.testing.allocator, r, viewOf(r), t0 + 1)) {
            .response => |hit| {
                defer hit.deinit();
                try std.testing.expectEqualStrings("stale", hit.body.?.getBytes());
                try std.testing.expectEqual(fetch.internal.CacheState.local, hit.cache_state);
            },
            else => return error.TestExpectedHit,
        }
    }
    const missing = try fx.request("http://a.test/none");
    defer missing.deinit();
    missing.cache_mode = .only_if_cached;
    try std.testing.expect(try Transaction.begin(std.testing.allocator, missing, viewOf(missing), t0) == .network_error);
}

test "hc1 transaction: reload stores without looking; no-store neither looks nor stores" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const fresh = [_]Field{.{ "Cache-Control", "max-age=60" }};
    const a = try fx.request("http://a.test/r");
    defer a.deinit();
    a.cache_mode = .no_store;
    try std.testing.expect(try Transaction.begin(std.testing.allocator, a, viewOf(a), t0) == .bypass);
    const b = try fx.request("http://a.test/r");
    defer b.deinit();
    b.cache_mode = .reload;
    (try exchange(b, try response(200, &fresh, "v1"), t0)).deinit();
    // reload again: to the network although a fresh one is stored.
    const c = try fx.request("http://a.test/r");
    defer c.deinit();
    c.cache_mode = .reload;
    (try exchange(c, try response(200, &fresh, "v2"), t0)).deinit();
    const d = try fx.request("http://a.test/r");
    defer d.deinit();
    switch (try Transaction.begin(std.testing.allocator, d, viewOf(d), t0)) {
        .response => |hit| {
            defer hit.deinit();
            try std.testing.expectEqualStrings("v2", hit.body.?.getBytes());
        },
        else => return error.TestExpectedHit,
    }
}

test "hc1 transaction: a default request the author made conditional is no-store (8.16)" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const r = try fx.request("http://a.test/x");
    defer r.deinit();
    try r.header_list.append("If-None-Match", "\"x\"");
    try std.testing.expect(try Transaction.begin(std.testing.allocator, r, viewOf(r), t0) == .bypass);
}

test "hc1 transaction: no network partition key, no cache - and a HEAD or a range request bypasses it" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const r = try fx.request("http://a.test/x");
    defer r.deinit();
    std.testing.allocator.free(r.network_partition_key.?);
    r.network_partition_key = null;
    try std.testing.expect(try Transaction.begin(std.testing.allocator, r, viewOf(r), t0) == .bypass);
    const head = try fx.request("http://a.test/x");
    defer head.deinit();
    try head.setMethod("HEAD");
    try std.testing.expect(try Transaction.begin(std.testing.allocator, head, viewOf(head), t0) == .bypass);
    const range = try fx.request("http://a.test/x");
    defer range.deinit();
    try range.header_list.append("Range", "bytes=0-1");
    try std.testing.expect(try Transaction.begin(std.testing.allocator, range, viewOf(range), t0) == .bypass);
    var off = try Fixture.init(.{ .max_bytes = 0 });
    defer off.deinit();
    try std.testing.expect(off.network.http_cache == null);
}

test "hc1 transaction: an unsafe method answered 2xx/3xx invalidates the URL; an error does not" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const url = "http://a.test/p";
    const get = try fx.request(url);
    defer get.deinit();
    (try exchange(get, try response(200, &.{.{ "Cache-Control", "max-age=60" }}, "x"), t0)).deinit();
    const failed = try fx.request(url);
    defer failed.deinit();
    try failed.setMethod("POST");
    (try exchange(failed, try response(500, &.{}, ""), t0)).deinit();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
    const posted = try fx.request(url);
    defer posted.deinit();
    try posted.setMethod("FROB");
    (try exchange(posted, try response(303, &.{.{ "Location", "/q" }}, ""), t0)).deinit();
    try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
}

test "hc1 transaction: a Vary mismatch revalidates with the ETag alone; only-if-cached fails" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const url = "http://a.test/vary";
    const first = try fx.request(url);
    defer first.deinit();
    try first.header_list.append("Accept-Language", "en");
    (try exchange(first, try response(200, &.{ .{ "Vary", "Accept-Language" }, .{ "ETag", "\"en\"" }, .{ "Last-Modified", "Sun, 06 Nov 1994 08:49:37 GMT" }, .{ "Cache-Control", "max-age=600" } }, "en"), t0)).deinit();
    const fr = try fx.request(url);
    defer fr.deinit();
    try fr.header_list.append("Accept-Language", "fr");
    var n = try expectNetwork(try Transaction.begin(std.testing.allocator, fr, viewOf(fr), t0 + 1));
    defer n.transaction.deinit();
    try std.testing.expectEqualStrings("\"en\"", n.if_none_match.?);
    try std.testing.expect(n.if_modified_since == null);
    // The same language: a hit; a Fetch-added header counts as well.
    const en = try fx.request(url);
    defer en.deinit();
    const added = [_]NetHeader{.{ .name = "Accept-Language", .value = "en" }};
    switch (try Transaction.begin(std.testing.allocator, en, .{ .author = en.header_list.iterator(), .added = &added }, t0 + 1)) {
        .response => |hit| hit.deinit(),
        else => return error.TestExpectedHit,
    }
    const offline = try fx.request(url);
    defer offline.deinit();
    offline.cache_mode = .only_if_cached;
    try std.testing.expect(try Transaction.begin(std.testing.allocator, offline, viewOf(offline), t0 + 1) == .network_error);
}

test "hc1 transaction: no-cache mode and a request max-age=0 revalidate a fresh response" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const url = "http://a.test/nc";
    const first = try fx.request(url);
    defer first.deinit();
    (try exchange(first, try response(200, &.{ .{ "ETag", "\"n\"" }, .{ "Cache-Control", "max-age=600" } }, "x"), t0)).deinit();
    const a = try fx.request(url);
    defer a.deinit();
    a.cache_mode = .no_cache;
    var na = try expectNetwork(try Transaction.begin(std.testing.allocator, a, viewOf(a), t0 + 1));
    na.transaction.deinit();
    try std.testing.expectEqualStrings("\"n\"", na.if_none_match.?);
    // resource-timing/sizes-cache.any.js's third fetch.
    const b = try fx.request(url);
    defer b.deinit();
    try b.header_list.append("Cache-Control", "max-age=0");
    var nb = try expectNetwork(try Transaction.begin(std.testing.allocator, b, viewOf(b), t0 + 1));
    nb.transaction.deinit();
    // A request no-store: no cache at all.
    const c = try fx.request(url);
    defer c.deinit();
    try c.header_list.append("Cache-Control", "no-store");
    try std.testing.expect(try Transaction.begin(std.testing.allocator, c, viewOf(c), t0 + 1) == .bypass);
}

test "hc1 transaction: what is not storable is not stored" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    const cases = [_]struct { u16, []const Field }{
        .{ 200, &.{.{ "Cache-Control", "no-store, max-age=60" }} },
        .{ 201, &.{} }, // not heuristically cacheable, nothing explicit
        .{ 206, &.{.{ "Cache-Control", "max-age=60" }} },
        .{ 302, &.{} },
    };
    for (cases, 0..) |case, i| {
        var buf: [64]u8 = undefined;
        const r = try fx.request(try std.fmt.bufPrint(&buf, "http://a.test/n{d}", .{i}));
        defer r.deinit();
        (try exchange(r, try response(case[0], case[1], ""), t0)).deinit();
    }
    try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
    // A 404 is heuristically cacheable: stored (and stale, so revalidated).
    const missing = try fx.request("http://a.test/404");
    defer missing.deinit();
    (try exchange(missing, try response(404, &.{}, "gone"), t0)).deinit();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
}

/// A response whose body arrives through a pipe the test feeds.
const Streamed = struct {
    source: *body_pipe.PipeSource,
    producer: Producer = .{},

    const Producer = struct {
        paused: bool = false,
        cancelled: bool = false,
        fn cancel(context: *anyopaque) void {
            const self: *Producer = @ptrCast(@alignCast(context));
            self.cancelled = true;
        }
        fn pause(context: *anyopaque) void {
            const self: *Producer = @ptrCast(@alignCast(context));
            self.paused = true;
        }
        fn unpause(context: *anyopaque) void {
            const self: *Producer = @ptrCast(@alignCast(context));
            self.paused = false;
        }
    };

    fn response(self: *Streamed, status: u16, fields: []const Field) !*InternalResponse {
        self.source = try body_pipe.PipeSource.create(std.testing.allocator);
        self.source.producer = .{ .context = &self.producer, .cancel = Producer.cancel, .pause = Producer.pause, .unpause = Producer.unpause };
        const pipe = try self.source.branch();
        const r = try InternalResponse.init(std.testing.allocator);
        r.status = status;
        for (fields) |f| try r.header_list.append(f[0], f[1]);
        r.body = try fetch.internal.Body.fromPipe(std.testing.allocator, pipe);
        return r;
    }
};

test "hc1 transaction: a body still arriving is stored once it has finished, and not if it fails" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    var streamed: Streamed = .{ .source = undefined };
    const r = try fx.request("http://a.test/stream");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(200, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    // Nothing stored at the head.
    try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
    streamed.source.push("hel");
    streamed.source.push("lo");
    streamed.source.finish();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
    handed.deinit();
    const again = try fx.request("http://a.test/stream");
    defer again.deinit();
    switch (try Transaction.begin(std.testing.allocator, again, viewOf(again), t0 + 1)) {
        .response => |hit| {
            defer hit.deinit();
            try std.testing.expectEqualStrings("hello", hit.body.?.getBytes());
            try std.testing.expectEqual(@as(u64, 5), hit.body_info.decoded_size);
        },
        else => return error.TestExpectedHit,
    }

    var failing: Streamed = .{ .source = undefined };
    const f = try fx.request("http://a.test/fails");
    defer f.deinit();
    const handed_failing = try exchange(f, try failing.response(200, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    failing.source.push("part");
    failing.source.fail(.{ .kind = .network });
    handed_failing.deinit();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
}

test "hc1 transaction: a slow reader and a body bigger than the entry cap leave nothing stored and nothing leaked" {
    var fx = try Fixture.init(.{ .max_bytes = 8 * 1024 * 1024, .max_entry_bytes = 512 * 1024 });
    defer fx.deinit();
    var streamed: Streamed = .{ .source = undefined };
    const r = try fx.request("http://a.test/big");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(200, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    defer handed.deinit();
    // The reader takes nothing: the producer still pauses at the high-water
    // mark (1 MiB), past the entry cap - the writer let the copy go.
    const chunk = @as([(64 * 1024)]u8, @splat('q'));
    while (!streamed.producer.paused) streamed.source.push(&chunk);
    streamed.source.finish();
    try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
}

test "hc1 transaction: a body whose readers all go is cancelled, not stored" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    var streamed: Streamed = .{ .source = undefined };
    const r = try fx.request("http://a.test/gone");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(200, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    streamed.source.push("abc");
    handed.deinit(); // the last reader goes: the transfer stops
    try std.testing.expect(streamed.producer.cancelled);
    try std.testing.expectEqual(@as(usize, 0), fx.store().entryCount());
}

test "hc1 transaction: a redirect is stored at once, without its body" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    var streamed: Streamed = .{ .source = undefined };
    const r = try fx.request("http://a.test/redirect");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(302, &.{ .{ "Location", "/target" }, .{ "Expires", "Thu, 01 Jan 2099 00:00:00 GMT" } }), t0);
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
    handed.deinit(); // HTTP fetch follows it: its pipe goes unread
    const again = try fx.request("http://a.test/redirect");
    defer again.deinit();
    switch (try Transaction.begin(std.testing.allocator, again, viewOf(again), t0 + 1)) {
        .response => |hit| {
            defer hit.deinit();
            try std.testing.expectEqual(@as(u16, 302), hit.status);
            try std.testing.expectEqualStrings("/target", hit.header_list.getFirstValue("Location").?);
        },
        else => return error.TestExpectedHit,
    }
}

test "hc1 transaction: the cache outlives nothing it should not - a writer ends after its network" {
    var streamed: Streamed = .{ .source = undefined };
    var fx = try Fixture.init(.{});
    const r = try fx.request("http://a.test/late");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(200, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    // The Browser's network ends while the body is still arriving.
    fx.deinit();
    streamed.source.push("late");
    streamed.source.finish();
    handed.deinit(); // the writer released the cache's core: no leak
}

test "hc1 transaction: a fresh 204 is stored at its head - main fetch drops a null body status's body" {
    var fx = try Fixture.init(.{});
    defer fx.deinit();
    var streamed: Streamed = .{ .source = undefined };
    const r = try fx.request("http://a.test/nobody");
    defer r.deinit();
    const handed = try exchange(r, try streamed.response(204, &.{.{ "Cache-Control", "max-age=60" }}), t0);
    // Main fetch step 20 makes a null body status's body null: the pipe goes
    // unread and the transfer stops.
    handed.deinit();
    try std.testing.expectEqual(@as(usize, 1), fx.store().entryCount());
    const again = try fx.request("http://a.test/nobody");
    defer again.deinit();
    switch (try Transaction.begin(std.testing.allocator, again, viewOf(again), t0 + 1)) {
        .response => |hit| {
            defer hit.deinit();
            try std.testing.expectEqual(@as(u16, 204), hit.status);
        },
        else => return error.TestExpectedHit,
    }
}
