//! Lane net-nav1 (Item 3): RFC 9110 §9.2.2 idempotent retry when a direct HTTP
//! connection closes with no response (`EmptyResponse`).

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const fetch = @import("fetch");
const InternalRequest = fetch.internal.InternalRequest;
const NetworkContext = fetch.network.NetworkContext;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

/// Loopback TCP server that:
/// - On `/close-once`: closes the first connection with 0 bytes (causing
///   libcurl CURLE_GOT_NOTHING -> NetworkError.EmptyResponse), and answers
///   200 OK with `"recovered"` on the second connection.
/// - On `/always-empty`: always closes immediately with 0 bytes.
const EmptyCloseServer = struct {
    allocator: Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    close_once_hits: std.atomic.Value(u32) = .init(0),
    always_empty_hits: std.atomic.Value(u32) = .init(0),

    fn start(allocator: Allocator) !*EmptyCloseServer {
        const self = try allocator.create(EmptyCloseServer);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{self});
        return self;
    }

    fn stop(self: *EmptyCloseServer) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn url(self: *const EmptyCloseServer, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn acceptLoop(self: *EmptyCloseServer) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const t = std.Thread.spawn(.{}, handleConn, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            t.detach();
        }
    }

    fn handleConn(self: *EmptyCloseServer, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);

        var in_buf: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &in_buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            reader.interface.fillMore() catch return;
        }
        const buf = reader.interface.buffered();
        const head_end = std.mem.indexOf(u8, buf, "\r\n\r\n").?;
        const head = buf[0..head_end];
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const path = parts.next() orelse return;

        var content_len: usize = 0;
        var lines = std.mem.splitSequence(u8, head, "\r\n");
        _ = lines.next();
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..colon], " "), "content-length")) {
                content_len = std.fmt.parseInt(usize, std.mem.trim(u8, line[colon + 1 ..], " "), 10) catch 0;
            }
        }
        const total = head_end + 4 + content_len;
        while (reader.interface.buffered().len < total) {
            reader.interface.fillMore() catch return;
        }

        if (std.mem.eql(u8, path, "/always-empty")) {
            _ = self.always_empty_hits.fetchAdd(1, .acq_rel);
            return; // Close with 0 bytes -> CURLE_GOT_NOTHING / EmptyResponse
        }

        if (std.mem.eql(u8, path, "/close-once")) {
            const hit = self.close_once_hits.fetchAdd(1, .acq_rel);
            if (hit == 0) return; // First attempt closes with 0 bytes -> EmptyResponse
            var out_buf: [512]u8 = undefined;
            var writer = stream.writer(std.testing.io, &out_buf);
            writer.interface.writeAll("HTTP/1.1 200 OK\r\nContent-Length: 9\r\nConnection: close\r\n\r\nrecovered") catch return;
            writer.interface.flush() catch return;
        }
    }
};

fn doRequest(allocator: Allocator, ctx: *NetworkContext, method: []const u8, url: []const u8, body: ?[]const u8) !struct { status: u16, is_error: bool, net_error: fetch.internal.response.NetError, body: []u8 } {
    const req = try InternalRequest.init(allocator, url);
    defer req.deinit();
    try req.setMethod(method);
    req.network = ctx;
    req.cache_mode = .no_store;
    if (body) |b| req.body = .{ .bytes = b };
    var result = try fetch.algorithms.fetch(allocator, req, .{});
    defer result.deinit();
    const bytes = if (result.response.body) |b| try allocator.dupe(u8, b.getBytes()) else try allocator.dupe(u8, "");
    return .{
        .status = result.response.status,
        .is_error = result.response.response_type == .@"error",
        .net_error = result.response.net_error,
        .body = bytes,
    };
}

test "Item 3: idempotent methods (GET, HEAD, OPTIONS, PUT, DELETE) retry once on EmptyResponse" {
    const allocator = testing.allocator;
    const server = try EmptyCloseServer.start(allocator);
    defer server.stop();

    var url_buf: [96]u8 = undefined;
    const close_once_url = try server.url(&url_buf, "/close-once");

    const cases = [_]struct { method: []const u8, body: ?[]const u8, expect_body: []const u8 }{
        .{ .method = "GET", .body = null, .expect_body = "recovered" },
        .{ .method = "HEAD", .body = null, .expect_body = "" },
        .{ .method = "OPTIONS", .body = null, .expect_body = "recovered" },
        .{ .method = "PUT", .body = "data", .expect_body = "recovered" },
        .{ .method = "DELETE", .body = null, .expect_body = "recovered" },
    };

    for (cases) |c| {
        var ctx = NetworkContext.init(allocator);
        defer ctx.deinit();

        server.close_once_hits.store(0, .release);
        const r = try doRequest(allocator, &ctx, c.method, close_once_url, c.body);
        defer allocator.free(r.body);
        try testing.expect(!r.is_error);
        try testing.expectEqual(@as(u16, 200), r.status);
        try testing.expectEqualStrings(c.expect_body, r.body);
        try testing.expectEqual(@as(u32, 2), server.close_once_hits.load(.acquire));
    }
}

test "Item 3: non-idempotent POST does NOT retry on EmptyResponse" {
    const allocator = testing.allocator;
    const server = try EmptyCloseServer.start(allocator);
    defer server.stop();

    var ctx = NetworkContext.init(allocator);
    defer ctx.deinit();

    var url_buf: [96]u8 = undefined;
    const close_once_url = try server.url(&url_buf, "/close-once");

    server.close_once_hits.store(0, .release);
    const r = try doRequest(allocator, &ctx, "POST", close_once_url, "payload");
    defer allocator.free(r.body);
    try testing.expect(r.is_error);
    try testing.expectEqual(fetch.internal.response.NetError.empty_response, r.net_error);
    try testing.expectEqual(@as(u32, 1), server.close_once_hits.load(.acquire));
}

test "Item 3: permanent EmptyResponse fails after at most one retry" {
    const allocator = testing.allocator;
    const server = try EmptyCloseServer.start(allocator);
    defer server.stop();

    var ctx = NetworkContext.init(allocator);
    defer ctx.deinit();

    var url_buf: [96]u8 = undefined;
    const empty_url = try server.url(&url_buf, "/always-empty");

    const r = try doRequest(allocator, &ctx, "GET", empty_url, null);
    defer allocator.free(r.body);
    try testing.expect(r.is_error);
    try testing.expectEqual(fetch.internal.response.NetError.empty_response, r.net_error);
    try testing.expectEqual(@as(u32, 2), server.always_empty_hits.load(.acquire));
}
