//! WHATWG WebSocket API Implementation
//!
//! This module implements the WebSocket API as defined by the WHATWG WebSocket Standard:
//! https://websockets.spec.whatwg.org/
//!
//! The implementation uses libcurl's WebSocket support (7.86.0+) for the underlying
//! RFC 6455 protocol handling, including:
//! - HTTP/1.1 Upgrade handshake
//! - Frame parsing and serialization
//! - Payload masking (client-to-server)
//! - Sec-WebSocket-Key/Accept validation
//! - TLS for wss:// URLs
//! - Automatic Ping/Pong handling
//!
//! ## Module Structure
//!
//! - `connection.zig` - WebSocket connection state machine and lifecycle
//! - `curl_backend.zig` - libcurl WebSocket backend implementation
//! - `close_codes.zig` - RFC 6455 close status codes
//! - `events.zig` - WebSocket-specific event types (CloseEvent, MessageEvent)
//!
//! ## Usage
//!
//! ```zig
//! const ws = @import("websocket");
//!
//! // Create a new WebSocket connection
//! var socket = try ws.WebSocket.init(allocator, "wss://example.com/socket", null);
//! defer socket.deinit();
//!
//! // Set up event handlers
//! socket.onopen = onOpenHandler;
//! socket.onmessage = onMessageHandler;
//! socket.onclose = onCloseHandler;
//! socket.onerror = onErrorHandler;
//!
//! // Send data
//! try socket.send("Hello, WebSocket!");
//!
//! // Close the connection
//! try socket.close(1000, "Goodbye");
//! ```
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/
//! - RFC 6455: https://datatracker.ietf.org/doc/html/rfc6455
//! - libcurl WebSocket: https://curl.se/libcurl/c/libcurl-ws.html

const std = @import("std");

// Export submodules
pub const close_codes = @import("close_codes.zig");
pub const connection = @import("connection.zig");
pub const curl_backend = @import("curl_backend.zig");

// Re-export common types
pub const CloseCodes = close_codes.CloseCodes;
pub const ConnectionState = connection.ConnectionState;
pub const WebSocketConnection = connection.WebSocketConnection;

// TODO: Export WebSocket interface once implemented
// pub const WebSocket = @import("../webidl/impls/WebSocket.zig").WebSocket;

test {
    std.testing.refAllDecls(@This());
}
