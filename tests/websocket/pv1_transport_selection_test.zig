const std = @import("std");
const accepts = @import("websocket").transport.acceptsHandshake;

test "the selected transport determines the WebSocket handshake status" {
    // RFC 6455 upgrade versus RFC 8441 extended CONNECT (RFC 9113 8.5).
    // A 2xx on h1 must never open a socket; 101 is invalid on h2.
    try std.testing.expect(accepts(false, 101));
    try std.testing.expect(!accepts(false, 200));
    try std.testing.expect(accepts(true, 200));
    try std.testing.expect(accepts(true, 204));
    try std.testing.expect(accepts(true, 299));
    try std.testing.expect(!accepts(true, 101));
    try std.testing.expect(!accepts(true, 199));
    try std.testing.expect(!accepts(true, 300));
    try std.testing.expect(!accepts(true, 401));
    try std.testing.expect(!accepts(true, 500));
}
