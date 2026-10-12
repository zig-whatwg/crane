//! A Browser's network context keeps its own connections (instances B3): its
//! connection share is made on its first transfer, used by every transfer
//! of its requests, and closed with it - when curl shuts each pooled
//! connection down, an HTTP/2 one with a GOAWAY. Another context, alive at
//! the same time, has a share of its own: one Browser never reuses (and so
//! never observes) another's connections. curl's global state is the
//! process's, and a context's end leaves it.

const std = @import("std");
const testing = std.testing;
const clock = @import("clock");
const fetch = @import("fetch");
const network = fetch.network;
const curl_backend = network.curl_backend;
const NetworkRequest = network.NetworkRequest;
const NetworkContext = network.NetworkContext;
const TestServer = @import("test_server.zig").TestServer;

/// A GET of `/get` on `server`, through a blocking backend, on `context`'s
/// connections, answered 200.
fn expectFetchOk(server: *TestServer, context: ?*NetworkContext) !void {
    var base_buf: [128]u8 = undefined;
    var url_buf: [256]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "{s}/get", .{server.getBaseUrl(&base_buf)});
    const backend = try network.LibcurlBackend.init(testing.allocator);
    defer backend.deinit();
    const request: NetworkRequest = .{ .url = url, .method = "GET", .headers = &.{}, .body = null, .network = context };
    var response = try backend.getBackend().send(testing.allocator, &request);
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
}

test "each network context has connections of its own, and its end leaves the other's working" {
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    // curl's global state, as a process holds it.
    try network.globalInit();
    defer network.globalCleanup();
    const references = curl_backend.globalReferences();

    // Two contexts at once, as two Browsers alive together.
    var first = NetworkContext.init(testing.allocator);
    var first_ended = false;
    defer if (!first_ended) first.deinit();
    var second = NetworkContext.init(testing.allocator);
    defer second.deinit();

    // No share until a transfer needs one.
    try testing.expect(first.share == null);
    try testing.expect(!first.share_tried);
    try expectFetchOk(server, &first);
    try expectFetchOk(server, &second);
    const first_share = first.connectionShare() orelse return error.NoShare;
    const second_share = second.connectionShare() orelse return error.NoShare;
    try testing.expect(first_share != second_share);
    // Asked again, a context answers its one share.
    try testing.expectEqual(first_share, first.connectionShare().?);

    // The first ends - its connections with it - and the second still
    // fetches through its own.
    first.deinit();
    first_ended = true;
    try expectFetchOk(server, &second);
    // A request with no context opens a connection of its own.
    try expectFetchOk(server, null);

    // The contexts took nothing of curl's global state.
    try testing.expectEqual(references, curl_backend.globalReferences());
}

test "two network contexts' shares lock independently: holding one's connection cache holds up none of the other's transfers" {
    const server = try TestServer.start(testing.allocator);
    defer server.stop();
    try network.globalInit();
    defer network.globalCleanup();

    var first = NetworkContext.init(testing.allocator);
    defer first.deinit();
    var second = NetworkContext.init(testing.allocator);
    defer second.deinit();
    try expectFetchOk(server, &first);
    try expectFetchOk(server, &second);

    // The first Browser's connection cache, held - as a transfer of it holds
    // it while it takes a connection.
    const held = first.connectionShare() orelse return error.NoShare;
    held.hold(.connect);
    var released = false;
    defer if (!released) held.release(.connect);

    // A transfer of the second Browser, on another thread, goes ahead.
    const Other = struct {
        server: *TestServer,
        network: *NetworkContext,
        done: std.atomic.Value(bool) = .init(false),
        result: anyerror!void = {},
        fn run(self: *@This()) void {
            self.result = expectFetchOk(self.server, self.network);
            self.done.store(true, .release);
        }
    };
    var other: Other = .{ .server = server, .network = &second };
    const thread = try std.Thread.spawn(.{}, Other.run, .{&other});
    var waited: usize = 0;
    while (!other.done.load(.acquire) and waited < 5_000) : (waited += 1) clock.sleep(std.time.ns_per_ms);
    const finished = other.done.load(.acquire);
    held.release(.connect);
    released = true;
    thread.join();
    try testing.expect(finished);
    try other.result;
}
