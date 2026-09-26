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
//! - `close_codes.zig` - RFC 6455 close status codes (1000-4999)
//! - `events.zig` - Event types for task queue integration
//! - `utf8.zig` - UTF-8 validation for text frames
//! - `binary_types.zig` - Binary data handling (Blob/ArrayBuffer)
//! - `send_buffer.zig` - Message queuing and bufferedAmount tracking
//!
//! ## Architecture
//!
//! ```
//! ┌─────────────────────────────────────────────────────────┐
//! │                   WebSocket Interface                    │
//! │               (src/webidl/impls/WebSocket.zig)          │
//! ├─────────────────────────────────────────────────────────┤
//! │                  WebSocketConnection                     │
//! │                   (connection.zig)                       │
//! │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
//! │  │ SendBuffer  │  │ CloseCodes  │  │ UTF-8 Validator │ │
//! │  └─────────────┘  └─────────────┘  └─────────────────┘ │
//! ├─────────────────────────────────────────────────────────┤
//! │                   CurlWebSocket                          │
//! │                  (curl_backend.zig)                      │
//! │         libcurl WebSocket API (7.86.0+)                 │
//! └─────────────────────────────────────────────────────────┘
//! ```
//!
//! ## Connection States
//!
//! Per WHATWG spec, WebSocket connections have four states:
//!
//! - **CONNECTING (0)**: Connection not yet established
//! - **OPEN (1)**: Connection established, communication possible
//! - **CLOSING (2)**: Close handshake in progress
//! - **CLOSED (3)**: Connection closed or could not be opened
//!
//! ## Close Codes
//!
//! RFC 6455 defines close status codes:
//!
//! - **1000**: Normal closure
//! - **1001**: Going away (endpoint navigating away)
//! - **1002**: Protocol error
//! - **1003**: Unsupported data type
//! - **1007**: Invalid payload data (bad UTF-8)
//! - **1008**: Policy violation
//! - **1009**: Message too big
//! - **1010**: Missing required extension
//! - **1011**: Internal server error
//! - **3000-3999**: Registered for libraries/frameworks
//! - **4000-4999**: Private use (application-specific)
//!
//! ## Binary Types
//!
//! The `binaryType` attribute controls how binary messages are exposed:
//!
//! - **"blob"**: Data exposed as Blob object (can spool to disk)
//! - **"arraybuffer"**: Data exposed as ArrayBuffer (memory-efficient)
//!
//! ## Events
//!
//! WebSocket fires four events:
//!
//! - **open**: Connection established
//! - **message**: Data received (text or binary)
//! - **error**: Error occurred
//! - **close**: Connection closed
//!
//! All events are dispatched via the task queue using "networking" task source.
//!
//! ## Status: what is wired, and what is not
//!
//! The live path is real: `src/webidl/impls/WebSocket.zig` drives
//! `WebSocketConnection`, which drives `curl_backend.zig`, which sets
//! `CURLOPT_CONNECT_ONLY = CURL_CONNECT_ONLY_WEBSOCKET`, runs the handshake on
//! a multi handle of its own so that it never blocks the event loop, and moves
//! frames with `curl_ws_send`/`curl_ws_recv`.
//!
//! - **Events** fire from the interface's pump, one event-loop turn at a time,
//!   in a window or a worker realm. `events.zig`'s `WebSocketEventQueue` is not
//!   on that path.
//! - **`bufferedAmount`** is `connection.OutgoingQueue`: frames the socket has
//!   not taken yet, drained at each turn, which is what lets a frame the socket
//!   takes only part of go out whole. `send_buffer.zig`'s `SendBuffer` is not on
//!   that path - it queues whole messages and cannot carry a part-sent one.
//!
//! Both unused modules compile and are tested; neither is reachable from the
//! live path.
//!
//! ## Usage Example
//!
//! ```zig
//! const websocket = @import("websocket");
//!
//! // Create connection (starts in CONNECTING state)
//! var conn = try websocket.WebSocketConnection.init(allocator, "wss://example.com/ws");
//! defer conn.deinit();
//!
//! // Establish it, a step per event-loop turn
//! try conn.startConnect(.{ .protocols = &.{"chat"} });
//! while (!try conn.pollConnect()) {}
//!
//! // Queue a message; `flush` pushes the queue on later turns
//! try conn.send(.text, "Hello, WebSocket!");
//!
//! // Receive a whole message (non-blocking)
//! var scratch: [4096]u8 = undefined;
//! if (try conn.receive(&scratch)) |msg| {
//!     _ = msg.data;
//! }
//!
//! // Start the closing handshake; `closed` says when it is done
//! try conn.close(1000, "Goodbye");
//! ```
//!
//! ## UTF-8 Validation
//!
//! Per RFC 6455, text frames must contain valid UTF-8. Invalid UTF-8
//! causes connection failure with close code 1007.
//!
//! For fragmented messages, use `Utf8Validator` for streaming validation:
//!
//! ```zig
//! var validator = websocket.Utf8Validator{};
//! for (fragments) |fragment| {
//!     if (!validator.validate(fragment)) {
//!         // Invalid UTF-8 - fail connection
//!         break;
//!     }
//! }
//! if (!validator.finalize()) {
//!     // Incomplete sequence at end - fail connection
//! }
//! ```
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/
//! - RFC 6455: https://datatracker.ietf.org/doc/html/rfc6455
//! - libcurl WebSocket: https://curl.se/libcurl/c/libcurl-ws.html
//! - W3C File API (Blob): https://www.w3.org/TR/FileAPI/

const std = @import("std");

// Export submodules
pub const close_codes = @import("close_codes.zig");
pub const connection = @import("connection.zig");
pub const curl_backend = @import("curl_backend.zig");
pub const send_buffer = @import("send_buffer.zig");
pub const events = @import("events.zig");
pub const utf8 = @import("utf8.zig");
pub const binary_types = @import("binary_types.zig");

// Re-export common types
pub const CloseCodes = close_codes.CloseCodes;
pub const ConnectionState = connection.ConnectionState;
pub const WebSocketConnection = connection.WebSocketConnection;
pub const SendBuffer = send_buffer.SendBuffer;
pub const MessageType = send_buffer.MessageType;
pub const QueuedMessage = send_buffer.QueuedMessage;

// Event types
pub const WebSocketEvent = events.WebSocketEvent;
pub const WebSocketEventType = events.WebSocketEventType;
pub const WebSocketEventTask = events.WebSocketEventTask;
pub const OpenEventData = events.OpenEventData;
pub const MessageEventData = events.MessageEventData;
pub const CloseEventData = events.CloseEventData;

// UTF-8 validation
pub const Utf8Validator = utf8.Utf8Validator;
pub const isValidUtf8 = utf8.isValidUtf8;

// Binary types
pub const BinaryBytes = binary_types.BinaryBytes;
pub const BinaryDataType = binary_types.BinaryDataType;
pub const MessageBinaryData = binary_types.MessageBinaryData;

// TODO: Export WebSocket interface once implemented
// pub const WebSocket = @import("../webidl/impls/WebSocket.zig").WebSocket;

test {
    std.testing.refAllDecls(@This());
}
