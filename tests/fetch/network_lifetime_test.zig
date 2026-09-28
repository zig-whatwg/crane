//! The network's process-wide state - curl, and the connection pool every
//! transfer shares - lives while anything holds it. A Browser holds it for
//! its life (Browser.init and Browser.deinit), so a later Browser must never
//! find it torn down under it, and the pool must end only with its last
//! holder. That is when curl shuts each pooled connection down, an HTTP/2
//! one with a GOAWAY. Before, nothing ever ended it: every connection closed
//! with the process, as a bare FIN.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");
const network = fetch.network;
const curl_backend = network.curl_backend;
const NetworkRequest = network.NetworkRequest;
const TestServer = @import("test_server.zig").TestServer;

/// A GET of `/get` on `server`, through a blocking backend, answered 200.
fn expectFetchOk(server: *TestServer) !void {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}/get", .{server.getBaseUrl(&base_buf)});
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    const request: NetworkRequest = .{ .url = url, .method = "GET", .headers = &.{}, .body = null };
    var response = try backend.getBackend().send(testing.allocator, &request);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
}

test "the connection pool ends with its last holder, and a later holder gets a new one" {
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    const base = curl_backend.globalReferences();

    // Two holders at once, as two Browsers alive together: the first to end
    // leaves the pool to the second, which still fetches through it.
    try network.globalInit();
    try network.globalInit();
    try expectFetchOk(server);
    network.globalCleanup();
    try testing.expect(curl_backend.getGlobalShare() != null);
    try expectFetchOk(server);
    network.globalCleanup();
    try testing.expectEqual(base, curl_backend.globalReferences());
    // With no other holder in this process, the pool is gone.
    if (base == 0) try testing.expect(curl_backend.getGlobalShare() == null);

    // One after the other, as a runner's Browsers in sequence: each finds a
    // working pool, made anew.
    try network.globalInit();
    try expectFetchOk(server);
    network.globalCleanup();
    try network.globalInit();
    try expectFetchOk(server);
    network.globalCleanup();
    try testing.expectEqual(base, curl_backend.globalReferences());
}
