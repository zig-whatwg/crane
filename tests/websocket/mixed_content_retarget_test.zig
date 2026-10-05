//! The handshake connects to Fetch's upgraded URL, before transport exists.
const std = @import("std");
const websocket = @import("websocket");
const Connection = websocket.WebSocketConnection;

test "WebSocket handshake URL is copied before connecting" {
    const connection = try Connection.init(std.testing.allocator, "ws://example.test:8443/echo");
    defer connection.deinit();
    var target = "wss://example.test:8443/echo".*;
    try connection.setHandshakeUrl(&target);
    target[0] = 'x';
    try std.testing.expectEqualStrings("wss://example.test:8443/echo", connection.url);
    try std.testing.expectEqual(websocket.ConnectionState.CONNECTING, connection.state);
    try std.testing.expect(connection.backend == null);
    try std.testing.expect(!connection.handshake_started);
}

test "WebSocket handshake URL cannot change after transport starts or closes" {
    const connection = try Connection.init(std.testing.allocator, "ws://example.test/echo");
    defer connection.deinit();
    connection.handshake_started = true;
    try std.testing.expectError(error.InvalidState, connection.setHandshakeUrl("wss://example.test/echo"));
    connection.handshake_started = false;
    connection.closed = true;
    try std.testing.expectError(error.InvalidState, connection.setHandshakeUrl("wss://example.test/echo"));
    connection.closed = false;
    connection.state = .OPEN;
    try std.testing.expectError(error.InvalidState, connection.setHandshakeUrl("wss://example.test/echo"));
    try std.testing.expectEqualStrings("ws://example.test/echo", connection.url);
}

test "WebSocket handshake URL allocation failure preserves the original URL" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const connection = try Connection.init(failing.allocator(), "ws://example.test/echo");
    defer connection.deinit();
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, connection.setHandshakeUrl("wss://example.test/echo"));
    try std.testing.expectEqualStrings("ws://example.test/echo", connection.url);
    try std.testing.expect(connection.backend == null);
    try std.testing.expectEqual(websocket.ConnectionState.CONNECTING, connection.state);
}
