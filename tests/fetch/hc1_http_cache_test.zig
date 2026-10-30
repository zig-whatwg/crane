//! The Browser's HTTP cache store (lane httpcache1): one stored response per
//! (network partition key, URL) - Fetch 2.8's "unique HTTP cache associated
//! with key", RFC 9111 2's cache key - looked up without allocating, LRU
//! within a byte cap and a per-entry cap (Chromium's MemBackendImpl:
//! max_size_/8, evict 10% more than needed), entries immutable and counted
//! so a reader keeps one that is replaced or evicted, and a core that a
//! body writer can outlive its owner's end in.
const std = @import("std");
const fetch = @import("fetch");
const cache = fetch.cache;
const HttpCache = cache.HttpCache;
const StoredResponse = cache.StoredResponse;
const HeaderView = cache.HeaderView;
const NetHeader = fetch.network.NetworkRequest.Header;

fn entry(allocator: std.mem.Allocator, partition: []const u8, url: []const u8, body: []const u8) !*StoredResponse {
    return StoredResponse.create(allocator, .{
        .partition = partition,
        .url = url,
        .status = 200,
        .status_message = "OK",
        .headers = &.{
            .{ .name = "Content-Type", .value = "text/plain" },
            .{ .name = "Cache-Control", .value = "max-age=60" },
        },
        .body = body,
        .request_time = 1000,
        .response_time = 1001,
    });
}

test "hc1 cache: a stored response is found by its partition and URL, and only by them" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    defer store.close();
    store.publish(try entry(allocator, "http://top.test", "http://a.test/x", "hello"));

    const found = store.lookup("http://top.test", "http://a.test/x") orelse return error.TestUnexpectedResult;
    defer found.release();
    try std.testing.expectEqualStrings("hello", found.body.bytes);
    try std.testing.expectEqual(@as(u16, 200), found.status);
    // Another partition is another cache (Fetch 2.8): a missing key is not
    // a shared one (docs/lessons/architecture-a-missing-partition-key-...).
    try std.testing.expect(store.lookup("http://other.test", "http://a.test/x") == null);
    try std.testing.expect(store.lookup("", "http://a.test/x") == null);
    try std.testing.expect(store.lookup("http://top.test", "http://a.test/y") == null);
    try std.testing.expectEqual(@as(usize, 1), store.entryCount());
}

test "hc1 cache: the cache key URL drops the fragment" {
    try std.testing.expectEqualStrings("http://a.test/x?q", cache.keyUrl("http://a.test/x?q#frag"));
    try std.testing.expectEqualStrings("http://a.test/x", cache.keyUrl("http://a.test/x"));
}

test "hc1 cache: a new response for the key replaces the old, which its reader keeps" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    defer store.close();
    store.publish(try entry(allocator, "p", "http://a.test/x", "old"));
    const held = store.lookup("p", "http://a.test/x").?;
    store.publish(try entry(allocator, "p", "http://a.test/x", "new"));
    // The reader's copy is intact after the replacement.
    try std.testing.expectEqualStrings("old", held.body.bytes);
    held.release();
    const now = store.lookup("p", "http://a.test/x").?;
    defer now.release();
    try std.testing.expectEqualStrings("new", now.body.bytes);
    try std.testing.expectEqual(@as(usize, 1), store.entryCount());
}

test "hc1 cache: freshening swaps in the updated response only if the old one is still stored" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    defer store.close();
    store.publish(try entry(allocator, "p", "http://a.test/x", "v1"));
    const stale = store.lookup("p", "http://a.test/x").?;
    defer stale.release();
    const updated = try stale.freshened(allocator, &.{.{ .name = "Cache-Control", .value = "max-age=600" }}, 2000, 2001);
    store.replace(stale, updated);
    const after = store.lookup("p", "http://a.test/x").?;
    defer after.release();
    try std.testing.expect(after == updated);
    // The body is shared, not copied.
    try std.testing.expect(after.body == stale.body);
    try std.testing.expectEqualStrings("max-age=600", after.header("Cache-Control").?);

    // A response stored meanwhile is not overwritten by an older update.
    store.publish(try entry(allocator, "p", "http://a.test/x", "v2"));
    const late = try stale.freshened(allocator, &.{}, 3000, 3001);
    store.replace(stale, late);
    const kept = store.lookup("p", "http://a.test/x").?;
    defer kept.release();
    try std.testing.expectEqualStrings("v2", kept.body.bytes);
}

test "hc1 cache: least recently used responses go first, down to 90% of the cap" {
    const allocator = std.testing.allocator;
    const one = try entry(allocator, "p", "http://a.test/0", &@as([100:0]u8, @splat('x')));
    const size = one.size;
    one.release();
    // Room for four entries; per-entry cap above one.
    const store = try HttpCache.create(allocator, .{ .max_bytes = size * 4 + size / 2, .max_entry_bytes = size * 2 });
    defer store.close();
    const urls = [_][]const u8{ "http://a.test/0", "http://a.test/1", "http://a.test/2", "http://a.test/3" };
    for (urls) |url| store.publish(try entry(allocator, "p", url, &@as([100:0]u8, @splat('x'))));
    try std.testing.expectEqual(@as(usize, 4), store.entryCount());
    // Use /0: /1 is now the least recently used.
    store.lookup("p", urls[0]).?.release();
    store.publish(try entry(allocator, "p", "http://a.test/4", &@as([100:0]u8, @splat('x'))));
    // Over the cap: evicted from the cold end until at most 90% of it is
    // used - /1 alone here (5 entries -> 4, under 4.05).
    const max = size * 4 + size / 2;
    try std.testing.expect(store.byteCount() <= max - max / 10);
    try std.testing.expect(store.lookup("p", urls[1]) == null);
    store.lookup("p", urls[2]).?.release();
    store.lookup("p", urls[3]).?.release();
    store.lookup("p", urls[0]).?.release();
    store.lookup("p", "http://a.test/4").?.release();
}

test "hc1 cache: a response bigger than the entry cap is not stored; the default cap is an eighth" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{ .max_bytes = 8000 });
    defer store.close();
    try std.testing.expectEqual(@as(usize, 1000), store.maxEntryBytes());
    store.publish(try entry(allocator, "p", "http://a.test/big", &@as([1200:0]u8, @splat('y'))));
    try std.testing.expect(store.lookup("p", "http://a.test/big") == null);
    try std.testing.expectEqual(@as(usize, 0), store.byteCount());
    const defaults = try HttpCache.create(allocator, .{});
    defer defaults.close();
    try std.testing.expectEqual(@as(usize, 50 * 1024 * 1024), defaults.config.max_bytes);
    try std.testing.expectEqual(@as(usize, 50 * 1024 * 1024 / 8), defaults.maxEntryBytes());
}

test "hc1 cache: invalidation removes the target URI in its partition only" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    defer store.close();
    store.publish(try entry(allocator, "p", "http://a.test/x", "1"));
    store.publish(try entry(allocator, "q", "http://a.test/x", "2"));
    store.invalidate("p", "http://a.test/x");
    try std.testing.expect(store.lookup("p", "http://a.test/x") == null);
    store.lookup("q", "http://a.test/x").?.release();
}

test "hc1 cache: clearing an origin removes its responses in every partition" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    defer store.close();
    store.publish(try entry(allocator, "p", "https://a.test/x", "1"));
    store.publish(try entry(allocator, "q", "https://a.test:443/y?z", "2"));
    store.publish(try entry(allocator, "p", "https://a.test:8443/x", "3"));
    store.publish(try entry(allocator, "p", "https://b.test/x", "4"));
    store.clearOrigin("https://a.test");
    try std.testing.expect(store.lookup("p", "https://a.test/x") == null);
    try std.testing.expect(store.lookup("q", "https://a.test:443/y?z") == null);
    store.lookup("p", "https://a.test:8443/x").?.release();
    store.lookup("p", "https://b.test/x").?.release();
}

test "hc1 cache: a writer's reference outlives the owner's close, and its publish is dropped" {
    const allocator = std.testing.allocator;
    const store = try HttpCache.create(allocator, .{});
    store.publish(try entry(allocator, "p", "http://a.test/x", "1"));
    store.retain(); // a body writer still collecting
    store.close(); // the Browser's network ends first
    // The core is still there for the writer, closed and empty.
    try std.testing.expectEqual(@as(usize, 0), store.entryCount());
    store.publish(try entry(allocator, "p", "http://a.test/y", "2"));
    try std.testing.expectEqual(@as(usize, 0), store.entryCount());
    store.release(); // the writer goes: the core is freed (no leak).
}

test "hc1 cache: Vary records the storing request's values; absent matches only absent; * never" {
    const allocator = std.testing.allocator;
    const stored = try StoredResponse.create(allocator, .{
        .partition = "p",
        .url = "http://a.test/v",
        .status = 200,
        .headers = &.{.{ .name = "Vary", .value = "Accept-Language, foo" }},
        .request = .{ .added = &[_]NetHeader{.{ .name = "accept-language", .value = "en,  fr" }} },
        .request_time = 1,
        .response_time = 1,
    });
    defer stored.release();
    // The same values, whitespace aside, and Foo absent on both sides.
    try std.testing.expect(stored.varyMatches(.{ .added = &[_]NetHeader{.{ .name = "Accept-Language", .value = " en,  fr " }} }));
    // Two lines combine (RFC 9111 4.1).
    try std.testing.expect(stored.varyMatches(.{ .added = &[_]NetHeader{
        .{ .name = "Accept-Language", .value = "en" },
        .{ .name = "accept-language", .value = " fr" },
    } }));
    try std.testing.expect(!stored.varyMatches(.{ .added = &[_]NetHeader{.{ .name = "Accept-Language", .value = "de" }} }));
    try std.testing.expect(!stored.varyMatches(.{}));
    try std.testing.expect(!stored.varyMatches(.{ .added = &[_]NetHeader{
        .{ .name = "Accept-Language", .value = "en,  fr" },
        .{ .name = "Foo", .value = "1" },
    } }));

    const star = try StoredResponse.create(allocator, .{
        .partition = "p",
        .url = "http://a.test/s",
        .status = 200,
        .headers = &.{.{ .name = "Vary", .value = "*" }},
        .request_time = 1,
        .response_time = 1,
    });
    defer star.release();
    try std.testing.expect(!star.varyMatches(.{}));
}

test "hc1 cache: storage drops Set-Cookie, Connection and what it names, and proxy fields (RFC 9111 3.1)" {
    const allocator = std.testing.allocator;
    const stored = try StoredResponse.create(allocator, .{
        .partition = "p",
        .url = "http://a.test/h",
        .status = 200,
        .headers = &.{
            .{ .name = "Set-Cookie", .value = "a=1" },
            .{ .name = "Connection", .value = "close, X-Hop" },
            .{ .name = "X-Hop", .value = "1" },
            .{ .name = "Keep-Alive", .value = "timeout=5" },
            .{ .name = "Proxy-Authenticate", .value = "Basic" },
            .{ .name = "X-Kept", .value = "yes" },
        },
        .request_time = 1,
        .response_time = 1,
    });
    defer stored.release();
    try std.testing.expectEqual(@as(usize, 1), stored.headers.len);
    try std.testing.expectEqualStrings("yes", stored.header("x-kept").?);
}

test "hc1 cache: a 304's fields replace the stored ones, except those the stored body depends on" {
    const allocator = std.testing.allocator;
    const stored = try StoredResponse.create(allocator, .{
        .partition = "p",
        .url = "http://a.test/u",
        .status = 200,
        .headers = &.{
            .{ .name = "Content-Type", .value = "text/plain" },
            .{ .name = "Content-Length", .value = "5" },
            .{ .name = "Content-Encoding", .value = "gzip" },
            .{ .name = "Access-Control-Expose-Headers", .value = "a" },
            .{ .name = "Access-Control-Expose-Headers", .value = "b" },
            .{ .name = "ETag", .value = "\"x\"" },
            .{ .name = "A", .value = "1" },
        },
        .body = "hello",
        .request_time = 1,
        .response_time = 1,
    });
    defer stored.release();
    const updated = try stored.freshened(allocator, &.{
        .{ .name = "Content-Type", .value = "text/html" },
        .{ .name = "Content-Length", .value = "0" },
        .{ .name = "Content-Encoding", .value = "br" },
        .{ .name = "access-control-expose-headers", .value = "c" },
        .{ .name = "A", .value = "2" },
        .{ .name = "B", .value = "3" },
        .{ .name = "Set-Cookie", .value = "x=1" },
        .{ .name = "Connection", .value = "keep-alive" },
    }, 10, 11);
    defer updated.release();
    try std.testing.expectEqualStrings("text/plain", updated.header("Content-Type").?);
    try std.testing.expectEqualStrings("5", updated.header("Content-Length").?);
    try std.testing.expectEqualStrings("gzip", updated.header("Content-Encoding").?);
    try std.testing.expectEqualStrings("c", updated.header("Access-Control-Expose-Headers").?);
    try std.testing.expectEqual(@as(usize, 1), updated.headerCount("Access-Control-Expose-Headers"));
    try std.testing.expectEqualStrings("2", updated.header("A").?);
    try std.testing.expectEqualStrings("3", updated.header("B").?);
    try std.testing.expect(updated.header("Set-Cookie") == null);
    try std.testing.expect(updated.header("Connection") == null);
    try std.testing.expectEqual(@as(i64, 10), updated.request_time);
    try std.testing.expectEqual(@as(i64, 11), updated.response_time);
    try std.testing.expectEqualStrings("hello", updated.body.bytes);
}

// Two threads publish and look up in one cache at once: every lookup sees a
// whole entry or none, nothing leaks (the DebugAllocator would say), and the
// counts add up.
test "hc1 cache: one cache shared by two threads stays consistent" {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    defer std.testing.expect(debug.deinit() == .ok) catch @panic("leak");
    const allocator = debug.allocator();
    const store = try HttpCache.create(allocator, .{ .max_bytes = 64 * 1024 });
    defer store.close();
    const Worker = struct {
        fn run(s: *HttpCache, a: std.mem.Allocator, tag: u8) void {
            var buf: [64]u8 = undefined;
            var i: usize = 0;
            while (i < 2000) : (i += 1) {
                const url = std.fmt.bufPrint(&buf, "http://a.test/{d}", .{i % 97}) catch unreachable;
                const e = entry(a, "p", url, &@as([200]u8, @splat(tag))) catch continue;
                s.publish(e);
                if (s.lookup("p", url)) |found| {
                    std.debug.assert(found.body.bytes.len == 200);
                    found.release();
                }
            }
        }
    };
    const a = try std.Thread.spawn(.{}, Worker.run, .{ store, allocator, 'a' });
    const b = try std.Thread.spawn(.{}, Worker.run, .{ store, allocator, 'b' });
    a.join();
    b.join();
    try std.testing.expect(store.byteCount() <= 64 * 1024);
}
