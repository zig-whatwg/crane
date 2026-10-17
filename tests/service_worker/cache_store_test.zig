//! A Browser's Cache Storage, engine-free: the name to cache map per storage
//! key, Query Cache and Request Matches Cached Item (ignoreSearch,
//! ignoreMethod, Vary), Batch Cache Operations' atomicity, and a deleted
//! cache that stays functional for the objects that still represent it -
//! over the platform's storage engine (the testing platform's memory store).

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const sw = @import("service_worker");
const cache = sw.cache;
const Storage = cache.store.Storage;
const records = cache.records;

fn noEvent(_: ?*anyopaque, _: *const platform.PlatformEvent) callconv(.c) void {}

const Fixture = struct {
    browser: *platform.BrowserPlatform,
    storage: Storage,

    fn init() !Fixture {
        return .{
            .browser = try platform.createBrowserPlatform(testing.allocator, &.{}, .{ .context = null, .post = noEvent }),
            .storage = Storage.init(testing.allocator),
        };
    }

    fn deinit(self: *Fixture) void {
        self.storage.deinit();
        platform.destroyBrowserPlatform(self.browser);
    }
};

/// A request record for `url` (borrowed strings: never freed).
fn request(url: []const u8, method: []const u8, headers: []const records.Header) records.StoredRequest {
    return .{ .url = @constCast(url), .method = @constCast(method), .headers = @constCast(headers) };
}

fn response(status: u16, headers: []const records.Header, body: ?[]const u8) records.StoredResponse {
    return .{ .status = status, .headers = @constCast(headers), .body = if (body) |b| @constCast(b) else null };
}

fn header(comptime name: []const u8, comptime value: []const u8) records.Header {
    return .{ .name = @constCast(name), .value = @constCast(value) };
}

test "the name to cache map: open makes a cache once, keys keeps the order, delete removes one, per storage key" {
    var f = try Fixture.init();
    defer f.deinit();
    const a = "https://a.test";
    const b = "https://b.test";

    try testing.expect(!try f.storage.hasCache(f.browser, a, "v1"));
    const v1 = try f.storage.openCache(f.browser, a, "v1");
    const v2 = try f.storage.openCache(f.browser, a, "v2");
    try testing.expectEqual(v1, try f.storage.openCache(f.browser, a, "v1"));
    try testing.expect(v1 != v2);
    try testing.expect(try f.storage.hasCache(f.browser, a, "v1"));
    // Another storage key sees nothing of it.
    try testing.expect(!try f.storage.hasCache(f.browser, b, "v1"));

    const names = try f.storage.cacheNames(f.browser, testing.allocator, a);
    defer {
        for (names) |n| testing.allocator.free(n);
        testing.allocator.free(names);
    }
    try testing.expectEqual(@as(usize, 2), names.len);
    try testing.expectEqualStrings("v1", names[0]);
    try testing.expectEqualStrings("v2", names[1]);

    try testing.expect(try f.storage.deleteCache(f.browser, a, "v1"));
    try testing.expect(!try f.storage.deleteCache(f.browser, a, "v1"));
    // Opened again, it is a new cache, at the end of the map.
    const again = try f.storage.openCache(f.browser, a, "v1");
    try testing.expect(again != v1);
    const after = try f.storage.cacheNames(f.browser, testing.allocator, a);
    defer {
        for (after) |n| testing.allocator.free(n);
        testing.allocator.free(after);
    }
    try testing.expectEqualStrings("v2", after[0]);
    try testing.expectEqualStrings("v1", after[1]);
}

test "put replaces what matches, Query Cache honours ignoreSearch, ignoreMethod and the fragment" {
    var f = try Fixture.init();
    defer f.deinit();
    const id = try f.storage.openCache(f.browser, "https://a.test", "c");

    const first = request("https://a.test/x?q=1", "GET", &.{});
    const second = request("https://a.test/x?q=2", "GET", &.{});
    const r200 = response(200, &.{}, "one");
    const r201 = response(201, &.{}, "two");
    _ = try f.storage.batch(f.browser, id, &.{
        .{ .kind = .put, .request = &first, .response = &r200 },
        .{ .kind = .put, .request = &second, .response = &r201 },
    });

    // Exact URL, fragment excluded.
    const exact = try f.storage.query(f.browser, testing.allocator, id, .{ .url = "https://a.test/x?q=1#frag" }, .{});
    defer records.freeEntries(testing.allocator, exact);
    try testing.expectEqual(@as(usize, 1), exact.len);
    try testing.expectEqualStrings("one", exact[0].response.body.?);

    const any_search = try f.storage.query(f.browser, testing.allocator, id, .{ .url = "https://a.test/x" }, .{ .ignore_search = true });
    defer records.freeEntries(testing.allocator, any_search);
    try testing.expectEqual(@as(usize, 2), any_search.len);
    try testing.expectEqualStrings("https://a.test/x?q=1", any_search[0].request.url);

    // A put of a matching request replaces the entry, which moves to the end.
    const r202 = response(202, &.{}, "three");
    _ = try f.storage.batch(f.browser, id, &.{.{ .kind = .put, .request = &first, .response = &r202 }});
    const all = try f.storage.query(f.browser, testing.allocator, id, null, .{});
    defer records.freeEntries(testing.allocator, all);
    try testing.expectEqual(@as(usize, 2), all.len);
    try testing.expectEqualStrings("https://a.test/x?q=2", all[0].request.url);
    try testing.expectEqual(@as(u16, 202), all[1].response.status);

    // Delete with ignoreSearch removes both; a second time, nothing.
    const query_request = request("https://a.test/x", "GET", &.{});
    try testing.expectEqual(@as(usize, 2), try f.storage.batch(f.browser, id, &.{.{ .kind = .delete, .request = &query_request, .options = .{ .ignore_search = true } }}));
    try testing.expectEqual(@as(usize, 0), try f.storage.batch(f.browser, id, &.{.{ .kind = .delete, .request = &query_request, .options = .{ .ignore_search = true } }}));
}

test "Request Matches Cached Item: Vary compares the named headers' combined values; Vary: * never matches" {
    const a = testing.allocator;
    const vary_cookie = [_]records.Header{header("Vary", "Cookies")};
    const cached_req = request("https://a.test/c", "GET", &.{header("Cookies", "is-for-cookie")});
    const cached_resp = response(200, &vary_cookie, "");
    try testing.expect(try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c", .headers = &.{header("cookies", "is-for-cookie")} }, &cached_req, &cached_resp, .{}));
    try testing.expect(!try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c", .headers = &.{header("Cookies", "is-good")} }, &cached_req, &cached_resp, .{}));
    try testing.expect(!try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &cached_req, &cached_resp, .{}));
    try testing.expect(try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &cached_req, &cached_resp, .{ .ignore_vary = true }));
    const star = response(200, &.{header("Vary", "*")}, "");
    try testing.expect(!try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &cached_req, &star, .{}));
    // A cached request that is not GET matches only with ignoreMethod.
    const post = request("https://a.test/c", "POST", &.{});
    try testing.expect(!try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &post, null, .{}));
    try testing.expect(try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &post, null, .{ .ignore_method = true }));
}

test "Request Matches Cached Item: an opaque response's record shows no Vary - its filtered header list is empty" {
    const a = testing.allocator;
    const cached_req = request("https://a.test/c", "GET", &.{header("Cookies", "is-for-cookie")});
    // The record keeps the internal response's headers, Vary among them.
    for (records.StoredResponse.opaque_types) |kind| {
        var kept = response(200, &.{header("Vary", "*")}, "x");
        kept.response_type = kind;
        try testing.expect(kept.hidesHeaders());
        try testing.expect(try cache.store.requestMatchesCachedItem(a, .{ .url = "https://a.test/c" }, &cached_req, &kept, .{}));
    }
    const basic = response(200, &.{header("Vary", "*")}, "x");
    try testing.expect(!basic.hidesHeaders());
}

test "Batch Cache Operations is atomic: a failing operation leaves the cache as it was" {
    var f = try Fixture.init();
    defer f.deinit();
    const id = try f.storage.openCache(f.browser, "https://a.test", "c");
    const kept = request("https://a.test/kept", "GET", &.{});
    const ok = response(200, &.{}, "kept");
    _ = try f.storage.batch(f.browser, id, &.{.{ .kind = .put, .request = &kept, .response = &ok }});

    const twice = request("https://a.test/twice", "GET", &.{});
    // Two puts of one request in a batch: InvalidStateError, nothing kept.
    try testing.expectError(error.InvalidStateError, f.storage.batch(f.browser, id, &.{
        .{ .kind = .delete, .request = &kept },
        .{ .kind = .put, .request = &twice, .response = &ok },
        .{ .kind = .put, .request = &twice, .response = &ok },
    }));
    // A non-GET or non-http(s) put: TypeError.
    const post = request("https://a.test/post", "POST", &.{});
    try testing.expectError(error.TypeError, f.storage.batch(f.browser, id, &.{.{ .kind = .put, .request = &post, .response = &ok }}));
    const data = request("data:,x", "GET", &.{});
    try testing.expectError(error.TypeError, f.storage.batch(f.browser, id, &.{.{ .kind = .put, .request = &data, .response = &ok }}));

    const all = try f.storage.query(f.browser, testing.allocator, id, null, .{});
    defer records.freeEntries(testing.allocator, all);
    try testing.expectEqual(@as(usize, 1), all.len);
    try testing.expectEqualStrings("https://a.test/kept", all[0].request.url);
}

test "a deleted cache stays functional for the objects that represent it, then its entries go" {
    var f = try Fixture.init();
    defer f.deinit();
    const id = try f.storage.openCache(f.browser, "https://a.test", "c");
    try f.storage.retain(id);
    const req = request("https://a.test/r", "GET", &.{});
    const ok = response(200, &.{}, "body");
    _ = try f.storage.batch(f.browser, id, &.{.{ .kind = .put, .request = &req, .response = &ok }});
    try testing.expect(try f.storage.deleteCache(f.browser, "https://a.test", "c"));

    // Still there for the object.
    const kept = try f.storage.query(f.browser, testing.allocator, id, null, .{});
    defer records.freeEntries(testing.allocator, kept);
    try testing.expectEqual(@as(usize, 1), kept.len);

    // Its last object goes: the next change removes the entries.
    f.storage.release(id);
    _ = try f.storage.openCache(f.browser, "https://a.test", "other");
    const gone = try f.storage.query(f.browser, testing.allocator, id, null, .{});
    defer records.freeEntries(testing.allocator, gone);
    try testing.expectEqual(@as(usize, 0), gone.len);
}

test "an entry's bytes read back as the same request and response" {
    const a = testing.allocator;
    var entry: records.Entry = .{
        .request = try request("https://a.test/r#f", "GET", &.{header("Accept", "x")}).clone(a),
        .response = try response(404, &.{ header("Vary", "Accept"), header("X", "y") }, null).clone(a),
    };
    defer entry.deinit(a);
    entry.request.reload_navigation = true;
    const bytes = try records.encode(a, &entry);
    defer a.free(bytes);
    var back = try records.decode(a, bytes);
    defer back.deinit(a);
    try testing.expectEqualStrings("https://a.test/r#f", back.request.url);
    try testing.expectEqualStrings("Accept", back.request.headers[0].name);
    try testing.expect(back.request.reload_navigation);
    try testing.expectEqual(@as(u16, 404), back.response.status);
    try testing.expect(back.response.body == null);
    try testing.expectEqual(@as(usize, 2), back.response.headers.len);
    try testing.expectError(error.Corrupt, records.decode(a, bytes[0 .. bytes.len - 1]));
}
