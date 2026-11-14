//! The HTTP cache keys a stored response on whether its request included
//! credentials (HTTP-network-or-cache fetch's includeCredentials, steps
//! 8.3-8.4), beside the network partition key and the URL: a response
//! fetched with cookies never answers a request sent without them, nor the
//! other way round. Chromium splits its cache this way
//! (net::features::kSplitCacheByIncludeCredentials, HttpCache's key "_cn"
//! prefix for a request that does not allow credentials) and Firefox too
//! (nsICachingChannel LOAD_ANONYMOUS: the "a," cache key prefix); Safari
//! keys the partition and the URL only. Fetch's own key is the partition
//! alone, and no newer spec is involved: the majority splits (golden
//! rule 2). html/cross-origin-embedder-policy/credentialless/cache.window.js:
//! a COEP:credentialless document's no-cors request omits credentials, and
//! must not be answered by the response its unsafe-none neighbour cached
//! with them.
const std = @import("std");
const fetch = @import("fetch");
const cache = fetch.cache;
const Transaction = cache.Transaction;
const HeaderView = cache.HeaderView;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const NetworkContext = fetch.network.NetworkContext;

const testing = std.testing;
const t0: i64 = 1_800_000_000;
const url = "https://b.test/resource";

const Fixture = struct {
    network: NetworkContext,

    fn init() !Fixture {
        var network = NetworkContext.init(testing.allocator);
        errdefer network.deinit();
        try network.configure(.{ .http_cache = .{} });
        return .{ .network = network };
    }

    fn deinit(self: *Fixture) void {
        self.network.deinit();
    }

    /// A no-cors request from https://a.test with `credentials`, its client's
    /// embedder policy `coep` (none: no policy container).
    fn request(self: *Fixture, credentials: fetch.internal.CredentialsMode, coep: ?[]const u8) !*InternalRequest {
        const r = try InternalRequest.init(testing.allocator, url);
        errdefer r.deinit();
        r.network = &self.network;
        r.network_partition_key = try testing.allocator.dupe(u8, "https://a.test");
        try r.setOrigin("https://a.test");
        r.mode = .no_cors;
        r.response_tainting = .@"opaque";
        r.credentials_mode = credentials;
        if (coep) |value| r.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(testing.allocator, .{
            .url = "https://a.test/",
            .coep = value,
            .environment_secure = true,
        }));
        return r;
    }
};

fn viewOf(request: *const InternalRequest) HeaderView {
    return .{ .author = request.header_list.iterator() };
}

fn fresh(body: []const u8) !*InternalResponse {
    const r = try InternalResponse.init(testing.allocator);
    errdefer r.deinit();
    r.status = 200;
    try r.header_list.append("Cache-Control", "max-age=31536000");
    r.body = try fetch.internal.Body.fromBytes(testing.allocator, body);
    return r;
}

/// Fetch `request` through the cache: the network's `answer` (taken) is
/// stored when the cache misses. Returns the body fetch goes on with and
/// whether the network was asked.
fn fetchThrough(request: *InternalRequest, answer: *InternalResponse, now: i64, body_out: *[16]u8) !struct { []const u8, bool } {
    switch (try Transaction.begin(testing.allocator, request, viewOf(request), now)) {
        .response => |hit| {
            answer.deinit();
            defer hit.deinit();
            const bytes = hit.body.?.getBytes();
            @memcpy(body_out[0..bytes.len], bytes);
            return .{ body_out[0..bytes.len], false };
        },
        .network => |n| {
            var network = n;
            defer network.transaction.deinit();
            const got = try network.transaction.afterNetwork(testing.allocator, request, viewOf(request), answer, now);
            defer got.deinit();
            const bytes = got.body.?.getBytes();
            @memcpy(body_out[0..bytes.len], bytes);
            return .{ body_out[0..bytes.len], true };
        },
        else => {
            answer.deinit();
            return error.TestUnexpectedBegin;
        },
    }
}

test "a response stored for a credentialed request does not answer one without credentials, nor the reverse" {
    var fx = try Fixture.init();
    defer fx.deinit();
    var buf: [16]u8 = undefined;

    const with = try fx.request(.include, null);
    defer with.deinit();
    const first = try fetchThrough(with, try fresh("cookies"), t0, &buf);
    try testing.expect(first[1]);

    // credentials "omit": a second request goes to the network.
    const without = try fx.request(.omit, null);
    defer without.deinit();
    const second = try fetchThrough(without, try fresh("anonymous"), t0 + 1, &buf);
    try testing.expect(second[1]);
    try testing.expectEqualStrings("anonymous", second[0]);

    // Each kind is answered from its own stored response.
    const with_again = try fx.request(.include, null);
    defer with_again.deinit();
    const third = try fetchThrough(with_again, try fresh("unused"), t0 + 2, &buf);
    try testing.expect(!third[1]);
    try testing.expectEqualStrings("cookies", third[0]);
    const without_again = try fx.request(.omit, null);
    defer without_again.deinit();
    const fourth = try fetchThrough(without_again, try fresh("unused"), t0 + 3, &buf);
    try testing.expect(!fourth[1]);
    try testing.expectEqualStrings("anonymous", fourth[0]);
    try testing.expectEqual(@as(usize, 2), fx.network.http_cache.?.entryCount());
}

test "a COEP:credentialless client's no-cors request is not answered by the response cached with credentials" {
    var fx = try Fixture.init();
    defer fx.deinit();
    var buf: [16]u8 = undefined;

    // The unsafe-none document: credentials "include" sends cookies.
    const none = try fx.request(.include, "unsafe-none");
    defer none.deinit();
    try testing.expect(fetch.algorithms.http_fetch.httpNetworkFetchUsesCookies(none));
    const first = try fetchThrough(none, try fresh("cookies"), t0, &buf);
    try testing.expect(first[1]);

    // The credentialless document: the same request omits them (8.4), so
    // the network is asked again.
    const credentialless = try fx.request(.include, "credentialless");
    defer credentialless.deinit();
    try testing.expect(!fetch.algorithms.http_fetch.httpNetworkFetchUsesCookies(credentialless));
    const second = try fetchThrough(credentialless, try fresh("anonymous"), t0 + 1, &buf);
    try testing.expect(second[1]);
    try testing.expectEqualStrings("anonymous", second[0]);
}

test "an unsafe method's success invalidates both stored responses of its URL" {
    var fx = try Fixture.init();
    defer fx.deinit();
    var buf: [16]u8 = undefined;
    const with = try fx.request(.include, null);
    defer with.deinit();
    _ = try fetchThrough(with, try fresh("cookies"), t0, &buf);
    const without = try fx.request(.omit, null);
    defer without.deinit();
    _ = try fetchThrough(without, try fresh("anonymous"), t0, &buf);
    try testing.expectEqual(@as(usize, 2), fx.network.http_cache.?.entryCount());

    // RFC 9111 4.4: "the target URI" - whichever kind of request stored it.
    const post = try fx.request(.include, null);
    defer post.deinit();
    try post.setMethod("POST");
    const answered = try fetchThrough(post, try fresh("posted"), t0 + 1, &buf);
    try testing.expect(answered[1]);
    try testing.expectEqual(@as(usize, 0), fx.network.http_cache.?.entryCount());
}

test "the cache's own key: lookup takes the credentials bit, invalidate removes both" {
    const allocator = testing.allocator;
    const store = try cache.HttpCache.create(allocator, .{});
    defer store.close();
    for ([_]bool{ true, false }) |credentialed| {
        store.publish(try cache.StoredResponse.create(allocator, .{
            .partition = "https://a.test",
            .url = url,
            .credentialed = credentialed,
            .status = 200,
            .headers = &.{.{ .name = "Cache-Control", .value = "max-age=60" }},
            .body = if (credentialed) "with" else "without",
            .request_time = t0,
            .response_time = t0,
        }));
    }
    const with = store.lookup("https://a.test", url, true).?;
    defer with.release();
    try testing.expectEqualStrings("with", with.body.bytes);
    const without = store.lookup("https://a.test", url, false).?;
    defer without.release();
    try testing.expectEqualStrings("without", without.body.bytes);
    store.invalidate("https://a.test", url);
    try testing.expectEqual(@as(usize, 0), store.entryCount());
    try testing.expect(store.lookup("https://a.test", url, true) == null);
    try testing.expect(store.lookup("https://a.test", url, false) == null);
}

test "a cached gzip, br or zstd response stores and returns the decoded body, its Content-Encoding and its filtered coding" {
    // HTTP-network fetch hands the cache a response whose body Fetch has
    // already decoded ("handle content codings", src/fetch/content_coding)
    // and whose header list still says how it was coded. The cache stores
    // that decoded body with the header (RFC 9111 3.2: Content-Encoding is
    // one of the fields a 304 does not update) and the body info's filtered
    // coding (Fetch 11.5.2's note: "the associated body info is stored in the
    // cache alongside the response"); a hit answers all three. The coding is
    // not part of the key: each credentials variant keeps its own response.
    for ([_][]const u8{ "gzip", "br", "zstd" }) |coding| {
        var fx = try Fixture.init();
        defer fx.deinit();
        const first = try fx.request(.include, null);
        defer first.deinit();
        const coded = try fresh("decoded text");
        try coded.header_list.append("Content-Encoding", coding);
        var buf: [16]u8 = undefined;
        _ = try fetchThrough(first, coded, t0, &buf);
        try testing.expectEqual(@as(usize, 1), fx.network.http_cache.?.entryCount());

        const again = try fx.request(.include, null);
        defer again.deinit();
        switch (try Transaction.begin(testing.allocator, again, viewOf(again), t0 + 1)) {
            .response => |hit| {
                defer hit.deinit();
                try testing.expectEqualStrings("decoded text", hit.body.?.getBytes());
                try testing.expectEqualStrings(coding, hit.header_list.getFirstValue("Content-Encoding").?);
                try testing.expectEqualStrings(coding, hit.body_info.content_encoding);
            },
            else => return error.TestExpectedHit,
        }
        // The uncredentialed request is not answered by it.
        const anonymous = try fx.request(.omit, null);
        defer anonymous.deinit();
        var network = switch (try Transaction.begin(testing.allocator, anonymous, viewOf(anonymous), t0 + 1)) {
            .network => |n| n,
            else => return error.TestExpectedNetwork,
        };
        network.transaction.deinit();
    }
}
