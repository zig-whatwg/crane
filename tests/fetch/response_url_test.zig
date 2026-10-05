//! A response's URL is its request's (Fetch main fetch: "If response's URL
//! list is empty, then set it to a clone of request's URL list"), against the
//! local test server.
//!
//! Fetch follows redirects itself - the network layer is told not to - so
//! the network's own idea of the URL it fetched is never the response's: curl
//! re-serializes the URL it was given, and its serialization drops an empty
//! query. A frame at `blank.html?` reported `location.href` as `blank.html`,
//! and a form submission to `blank.html?#foo` was no longer a fragment
//! navigation (navigation-api/navigate-event/cross-window/
//! submit-samedocument-crossorigin.html).

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;
const TestServer = @import("test_server.zig").TestServer;

fn fetchUrl(allocator: std.mem.Allocator, url: []const u8) !fetch.algorithms.FetchResult {
    const request = try InternalRequest.init(allocator, url);
    defer request.deinit();
    return fetch.algorithms.fetch(allocator, request, .{});
}

test "response URL - an empty query is the request's, kept" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var base_buf: [128]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}/get?", .{base});

    var result = try fetchUrl(allocator, url);
    defer result.deinit();
    try testing.expectEqual(@as(usize, 1), result.response.url_list.items.len);
    try testing.expectEqualStrings(url, result.response.url_list.items[0]);
}

test "response URL - a URL the network would re-serialize is the request's, as given" {
    const allocator = testing.allocator;
    try fetch.network.globalInit();
    defer fetch.network.globalCleanup();
    const server = try TestServer.start(allocator);
    defer server.stop();

    var base_buf: [128]u8 = undefined;
    const base = server.getBaseUrl(&base_buf);
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}/get?a=1&", .{base});

    var result = try fetchUrl(allocator, url);
    defer result.deinit();
    try testing.expectEqualStrings(url, result.response.url_list.items[0]);
}
