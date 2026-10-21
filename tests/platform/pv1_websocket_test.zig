const std = @import("std");
const platform = @import("platform");

fn pendingCancel(allocator: std.mem.Allocator) !void {
    const fields = [_]platform.Header{
        .{ .name = .from("Origin"), .value = .from("http://example.test") },
        .{ .name = .from("Sec-WebSocket-Protocol"), .value = .from("echo, chat") },
        .{ .name = .from("Cookie"), .value = .from("session=one") },
    };
    const socket = try platform.openWebSocket(allocator, &.{ .url = .from("ws://127.0.0.1:0/echo"), .headers = .from(&fields) });
    defer platform.releaseWebSocket(socket);
    // Cancel before the first poll: every handle/header is still owned exactly once.
}

test "WebSocket transport cancellation releases every partially allocated request" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, pendingCancel, .{});
}

test "WebSocket transport rejects injected headers and releases its setup" {
    const bad = [_]platform.Header{.{ .name = .from("Origin"), .value = .from("http://example.test\r\nInjected: yes") }};
    try std.testing.expectError(error.InvalidRequest, platform.openWebSocket(std.testing.allocator, &.{
        .url = .from("ws://127.0.0.1:0/echo"),
        .headers = .from(&bad),
    }));
}
