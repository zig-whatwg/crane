//! HTTP-redirect fetch, end to end against the local test server.
//!
//! Spec: https://fetch.spec.whatwg.org/#http-redirect-fetch
//!
//! `httpRedirectFetch` used to free the redirect response and then read its
//! status (`response.deinit(); if (response.status == 303)`), which is a
//! use-after-free that took down `fetch/api/redirect/redirect-location.any.js`,
//! `redirect-mode.any.js`, `redirect-to-dataurl.any.js` and
//! `cors/cors-redirect.any.js`. It also re-requested the redirecting URL before
//! following it, and appended the raw `Location` value to the URL list without
//! parsing it, so a relative location became a URL-list entry that was not a
//! URL at all.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;
const TestServer = @import("test_server.zig").TestServer;

/// Fetch `path` on the test server with `method`, following redirects.
fn fetchPath(
    allocator: std.mem.Allocator,
    server: *TestServer,
    method: []const u8,
    path: []const u8,
    body: ?[]const u8,
) !fetch.algorithms.FetchResult {
    var base_buf: [128]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base, path });

    const request = try InternalRequest.init(allocator, url);
    defer request.deinit();
    try request.setMethod(method);
    if (body) |b| request.body = .{ .bytes = b };

    return fetch.algorithms.fetch(allocator, request, .{});
}

fn expectPathSuffix(url: []const u8, suffix: []const u8) !void {
    if (!std.mem.endsWith(u8, url, suffix)) {
        std.debug.print("expected a URL ending in {s}, got {s}\n", .{ suffix, url });
        return error.TestUnexpectedResult;
    }
}

test "redirect - a root-relative Location is parsed against the response URL" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var result = try fetchPath(allocator, server, "GET", "/redirect-abs", null);
    defer result.deinit();

    try testing.expectEqual(@as(u16, 200), result.response.status);
    // Step 18: the location URL is appended to the URL list, so the response
    // reports both hops and `redirected` is true.
    try testing.expectEqual(@as(usize, 2), result.response.url_list.items.len);
    try expectPathSuffix(result.response.url_list.items[0], "/redirect-abs");
    try expectPathSuffix(result.response.url_list.items[1], "/get");
    // A URL, not the raw header value.
    try testing.expect(std.mem.startsWith(u8, result.response.url_list.items[1], "http://127.0.0.1:"));
}

test "redirect - a path-relative Location resolves against the redirecting URL" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var result = try fetchPath(allocator, server, "GET", "/redirect-rel", null);
    defer result.deinit();

    try testing.expectEqual(@as(u16, 200), result.response.status);
    try expectPathSuffix(result.response.url_list.items[result.response.url_list.items.len - 1], "/get");
}

test "redirect - 303 turns a POST into a GET and drops the body" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    // `/get` answers only GET; a POST that survived the redirect would 404.
    var result = try fetchPath(allocator, server, "POST", "/redirect-303", "payload");
    defer result.deinit();

    try testing.expectEqual(@as(u16, 200), result.response.status);
}

test "redirect - 307 keeps the method" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    // `/post` answers only POST.
    var result = try fetchPath(allocator, server, "POST", "/redirect-307", "payload");
    defer result.deinit();

    try testing.expectEqual(@as(u16, 200), result.response.status);
}

test "redirect - the twenty-first redirect is a network error" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var result = try fetchPath(allocator, server, "GET", "/redirect-loop", null);
    defer result.deinit();

    // Step 7: "If request's redirect count is 20, then return a network error."
    try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
    try testing.expectEqual(@as(u16, 0), result.response.status);
}

test "redirect - no Location header returns the redirect response itself" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var result = try fetchPath(allocator, server, "GET", "/redirect-none", null);
    defer result.deinit();

    // Step 4: "If locationURL is null, then return response."
    try testing.expectEqual(@as(u16, 302), result.response.status);
}

test "redirect - a Location that is not HTTP(S) is a network error" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var result = try fetchPath(allocator, server, "GET", "/redirect-ftp", null);
    defer result.deinit();

    // Step 6.
    try testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
}
