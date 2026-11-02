//! The loopback test server's held routes (module1_http_server.zig): a held
//! route counts a request when it arrives and answers it only once the test
//! releases the route - or the server stops, so that a test that never
//! releases cannot keep a connection, or the process, waiting.
const std = @import("std");
const clock = @import("clock");
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/held", .content_type = "text/plain", .body = "late", .held = true },
};

/// The most a step here waits for the server's thread.
const limit_ms = 10 * std.time.ms_per_s;

/// A request for `path` on a connection of its own, sent and flushed.
fn send(server: *const http.Server, path: []const u8) !std.Io.net.Stream {
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(server.server.socket.address.getPort()) };
    const stream = try address.connect(std.testing.io, .{ .mode = .stream });
    errdefer stream.close(std.testing.io);
    var buffer: [256]u8 = undefined;
    var writer = stream.writer(std.testing.io, &buffer);
    try writer.interface.print("GET {s} HTTP/1.1\r\nHost: held.test\r\nConnection: close\r\n\r\n", .{path});
    try writer.interface.flush();
    return stream;
}

/// Wait until the server has counted `n` requests for `path`.
fn waitForCount(server: *const http.Server, path: []const u8, n: u32) !void {
    const deadline = clock.monotonicMillis() + limit_ms;
    while (server.count(path) < n) {
        if (clock.monotonicMillis() >= deadline) return error.TestRequestNeverArrived;
        clock.sleep(std.time.ns_per_ms);
    }
}

test "a held route counts the request at once and answers it only after release" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const stream = try send(server, "/held");
    defer stream.close(std.testing.io);
    try waitForCount(server, "/held", 1);
    // Not answered while held: a server that answered at once would have
    // done so within this wait (no false failure is possible here).
    clock.sleep(50 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(u32, 0), server.answered("/held"));

    server.release("/held");
    // The whole answer, up to the connection's close.
    var buffer: [1024]u8 = undefined;
    var reader = stream.reader(std.testing.io, &buffer);
    while (true) reader.interface.fillMore() catch |err| switch (err) {
        error.EndOfStream => break,
        else => return err,
    };
    const response = reader.interface.buffered();
    try std.testing.expect(std.mem.startsWith(u8, response, "HTTP/1.1 200 OK\r\n"));
    try std.testing.expect(std.mem.endsWith(u8, response, "\r\n\r\nlate"));
    try std.testing.expectEqual(@as(u32, 1), server.answered("/held"));
}

test "stopping the server ends a held request that was never released" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    const stream = try send(server, "/held");
    defer stream.close(std.testing.io);
    try waitForCount(server, "/held", 1);
    // stop() waits for every connection it is answering: a held one must
    // not keep it waiting.
    const started = clock.monotonicMillis();
    server.stop();
    try std.testing.expect(clock.monotonicMillis() - started < limit_ms);
}
