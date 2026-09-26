//! WebSocket Integration Tests
//!
//! Tests for the WebSocket module implementation covering:
//! - Close codes validation
//! - Connection state management
//! - UTF-8 validation
//! - Binary type handling
//! - Event creation
//! - Send buffer operations
//!
//! Note: These are unit/integration tests that don't require a real
//! WebSocket server. Network integration tests would require a test server.

const std = @import("std");
const testing = std.testing;
const websocket = @import("websocket");

// =============================================================================
// Close Codes Tests
// =============================================================================

test "CloseCodes - standard codes" {
    try testing.expectEqual(@as(u16, 1000), websocket.CloseCodes.NORMAL_CLOSURE);
    try testing.expectEqual(@as(u16, 1001), websocket.CloseCodes.GOING_AWAY);
    try testing.expectEqual(@as(u16, 1002), websocket.CloseCodes.PROTOCOL_ERROR);
    try testing.expectEqual(@as(u16, 1003), websocket.CloseCodes.UNSUPPORTED_DATA);
    try testing.expectEqual(@as(u16, 1005), websocket.CloseCodes.NO_STATUS_RECEIVED);
    try testing.expectEqual(@as(u16, 1006), websocket.CloseCodes.ABNORMAL_CLOSURE);
    try testing.expectEqual(@as(u16, 1007), websocket.CloseCodes.INVALID_FRAME_PAYLOAD_DATA);
    try testing.expectEqual(@as(u16, 1008), websocket.CloseCodes.POLICY_VIOLATION);
    try testing.expectEqual(@as(u16, 1009), websocket.CloseCodes.MESSAGE_TOO_BIG);
    try testing.expectEqual(@as(u16, 1010), websocket.CloseCodes.MANDATORY_EXTENSION);
    try testing.expectEqual(@as(u16, 1011), websocket.CloseCodes.INTERNAL_ERROR);
    try testing.expectEqual(@as(u16, 1015), websocket.CloseCodes.TLS_HANDSHAKE);
}

test "CloseCodes - isValidForCloseFrame" {
    // Valid codes
    try testing.expect(websocket.CloseCodes.isValidForCloseFrame(1000)); // Normal
    try testing.expect(websocket.CloseCodes.isValidForCloseFrame(1001)); // Going away
    try testing.expect(websocket.CloseCodes.isValidForCloseFrame(3000)); // Registered
    try testing.expect(websocket.CloseCodes.isValidForCloseFrame(4000)); // Private use
    try testing.expect(websocket.CloseCodes.isValidForCloseFrame(4999)); // Private use max

    // Invalid codes
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(0)); // Too low
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(999)); // Below range
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(1004)); // Reserved
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(1005)); // Cannot send
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(1006)); // Cannot send
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(1015)); // Cannot send
    try testing.expect(!websocket.CloseCodes.isValidForCloseFrame(5000)); // Above range
}

test "CloseCodes - getDescription" {
    try testing.expectEqualStrings("Normal Closure", websocket.CloseCodes.getDescription(1000));
    try testing.expectEqualStrings("Going Away", websocket.CloseCodes.getDescription(1001));
    try testing.expectEqualStrings("Protocol Error", websocket.CloseCodes.getDescription(1002));
    try testing.expectEqualStrings("Reserved", websocket.CloseCodes.getDescription(1004));
    try testing.expectEqualStrings("Registered", websocket.CloseCodes.getDescription(3500));
    try testing.expectEqualStrings("Private Use", websocket.CloseCodes.getDescription(4500));
    try testing.expectEqualStrings("Unknown", websocket.CloseCodes.getDescription(5000));
}

// =============================================================================
// Connection State Tests
// =============================================================================

test "ConnectionState - values match spec" {
    try testing.expectEqual(@as(u16, 0), websocket.ConnectionState.CONNECTING.toReadyState());
    try testing.expectEqual(@as(u16, 1), websocket.ConnectionState.OPEN.toReadyState());
    try testing.expectEqual(@as(u16, 2), websocket.ConnectionState.CLOSING.toReadyState());
    try testing.expectEqual(@as(u16, 3), websocket.ConnectionState.CLOSED.toReadyState());
}

test "ConnectionState - canSend" {
    try testing.expect(!websocket.ConnectionState.CONNECTING.canSend());
    try testing.expect(websocket.ConnectionState.OPEN.canSend());
    try testing.expect(!websocket.ConnectionState.CLOSING.canSend());
    try testing.expect(!websocket.ConnectionState.CLOSED.canSend());
}

test "ConnectionState - isTerminal" {
    try testing.expect(!websocket.ConnectionState.CONNECTING.isTerminal());
    try testing.expect(!websocket.ConnectionState.OPEN.isTerminal());
    try testing.expect(!websocket.ConnectionState.CLOSING.isTerminal());
    try testing.expect(websocket.ConnectionState.CLOSED.isTerminal());
}

// =============================================================================
// UTF-8 Validation Tests
// =============================================================================

test "UTF8 - valid ASCII" {
    try testing.expect(websocket.isValidUtf8("Hello, World!"));
    try testing.expect(websocket.isValidUtf8(""));
    try testing.expect(websocket.isValidUtf8("0123456789"));
}

test "UTF8 - valid multi-byte" {
    try testing.expect(websocket.isValidUtf8("日本語")); // Japanese
    try testing.expect(websocket.isValidUtf8("🎉🚀💻")); // Emoji
    try testing.expect(websocket.isValidUtf8("Ελληνικά")); // Greek
    try testing.expect(websocket.isValidUtf8("العربية")); // Arabic
}

test "UTF8 - invalid sequences" {
    // Invalid continuation byte
    try testing.expect(!websocket.isValidUtf8(&[_]u8{0x80}));
    // Truncated sequence
    try testing.expect(!websocket.isValidUtf8(&[_]u8{0xC2}));
    // Overlong encoding
    try testing.expect(!websocket.isValidUtf8(&[_]u8{ 0xC0, 0x80 }));
}

test "Utf8Validator - streaming" {
    var validator = websocket.Utf8Validator{};

    // Split "Hello" across chunks
    try testing.expect(validator.validate("Hel"));
    try testing.expect(validator.validate("lo"));
    try testing.expect(validator.finalize());
}

test "Utf8Validator - multi-byte split" {
    var validator = websocket.Utf8Validator{};

    // "日" = E6 97 A5 split across chunks
    try testing.expect(validator.validate(&[_]u8{0xE6}));
    try testing.expect(validator.validate(&[_]u8{ 0x97, 0xA5 }));
    try testing.expect(validator.finalize());
}

test "Utf8Validator - incomplete sequence fails" {
    var validator = websocket.Utf8Validator{};

    try testing.expect(validator.validate(&[_]u8{0xE6})); // Start of 3-byte
    try testing.expect(!validator.finalize()); // Incomplete = fail
}

// =============================================================================
// Binary Types Tests
// =============================================================================

test "BinaryBytes - borrowed" {
    const data = "test data";
    var bytes = websocket.BinaryBytes.borrowed(data);

    try testing.expectEqualStrings(data, bytes.bytes);
    try testing.expect(!bytes.is_owned);

    bytes.deinit(); // Should not crash
}

test "BinaryBytes - owned" {
    const data = "test data";
    var bytes = try websocket.BinaryBytes.createOwned(testing.allocator, data);
    defer bytes.deinit();

    try testing.expectEqualStrings(data, bytes.bytes);
    try testing.expect(bytes.is_owned);
}

test "MessageBinaryData - text" {
    const data = "Hello";
    const result = try websocket.binary_types.createMessageBinaryData(testing.allocator, data, true);

    try testing.expect(result == .text);
    try testing.expectEqualStrings("Hello", result.text);
}

test "MessageBinaryData - binary" {
    const data = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    var result = try websocket.binary_types.createMessageBinaryData(testing.allocator, &data, false);
    defer result.binary.deinit();

    try testing.expect(result == .binary);
    try testing.expectEqualSlices(u8, &data, result.binary.bytes);
}

// =============================================================================
// Events Tests
// =============================================================================

test "WebSocketEventTask - create open" {
    var dummy: u8 = 0;
    const task = websocket.WebSocketEventTask.createOpen(
        testing.allocator,
        &dummy,
        "permessage-deflate",
        "graphql",
    );

    try testing.expect(task.event == .open);
    try testing.expectEqualStrings("permessage-deflate", task.event.open.extensions.?);
    try testing.expectEqualStrings("graphql", task.event.open.protocol.?);
}

test "WebSocketEventTask - create message" {
    var dummy: u8 = 0;
    const task = websocket.WebSocketEventTask.createMessage(
        testing.allocator,
        &dummy,
        "Hello, WebSocket!",
        true,
        "wss://example.com/socket",
    );

    try testing.expect(task.event == .message);
    try testing.expectEqualStrings("Hello, WebSocket!", task.event.message.data);
    try testing.expect(task.event.message.is_text);
    try testing.expectEqualStrings("wss://example.com/socket", task.event.message.origin);
}

test "WebSocketEventTask - create close" {
    var dummy: u8 = 0;
    const task = websocket.WebSocketEventTask.createClose(
        testing.allocator,
        &dummy,
        true,
        1000,
        "Normal closure",
    );

    try testing.expect(task.event == .close);
    try testing.expect(task.event.close.was_clean);
    try testing.expectEqual(@as(u16, 1000), task.event.close.code);
    try testing.expectEqualStrings("Normal closure", task.event.close.reason);
}

test "WebSocketEventTask - create error" {
    var dummy: u8 = 0;
    const task = websocket.WebSocketEventTask.createError(testing.allocator, &dummy);

    try testing.expect(task.event == .@"error");
}

// =============================================================================
// Send Buffer Tests
// =============================================================================

test "SendBuffer - basic operations" {
    var buffer = websocket.SendBuffer.init(testing.allocator);
    defer buffer.deinit();

    try testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
    try testing.expect(buffer.isEmpty());
}

test "SendBuffer - queue text message" {
    var buffer = websocket.SendBuffer.init(testing.allocator);
    defer buffer.deinit();

    try buffer.queueText("Hello, World!");

    try testing.expect(!buffer.isEmpty());
    try testing.expectEqual(@as(u64, 13), buffer.getBufferedAmount());
}

test "SendBuffer - queue binary message" {
    var buffer = websocket.SendBuffer.init(testing.allocator);
    defer buffer.deinit();

    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    try buffer.queueBinary(&data);

    try testing.expect(!buffer.isEmpty());
    try testing.expectEqual(@as(u64, 4), buffer.getBufferedAmount());
}

test "SendBuffer - dequeue preserves order" {
    var buffer = websocket.SendBuffer.init(testing.allocator);
    defer buffer.deinit();

    try buffer.queueText("First");
    try buffer.queueText("Second");
    try buffer.queueText("Third");

    const first = buffer.dequeue().?;
    try testing.expectEqualStrings("First", first.data);

    const second = buffer.dequeue().?;
    try testing.expectEqualStrings("Second", second.data);

    const third = buffer.dequeue().?;
    try testing.expectEqualStrings("Third", third.data);

    try testing.expect(buffer.dequeue() == null);
}

test "SendBuffer - markTransmitted updates bufferedAmount" {
    var buffer = websocket.SendBuffer.init(testing.allocator);
    defer buffer.deinit();

    try buffer.queueText("Hello"); // 5 bytes
    try testing.expectEqual(@as(u64, 5), buffer.getBufferedAmount());

    buffer.markTransmitted(5);
    try testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
}

test "SendBuffer - max size limit" {
    var buffer = websocket.SendBuffer.initWithLimit(testing.allocator, 10);
    defer buffer.deinit();

    try buffer.queueText("Hello"); // 5 bytes
    try testing.expectError(error.BufferFull, buffer.queueText("World!")); // Would exceed 10
}

// =============================================================================
// WebSocketConnection Tests (without network)
// =============================================================================

test "WebSocketConnection - initialization" {
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "wss://example.com/socket");
    defer conn.deinit();

    try testing.expectEqual(websocket.ConnectionState.CONNECTING, conn.state);
    try testing.expectEqualStrings("wss://example.com/socket", conn.url);
    try testing.expect(conn.protocol == null);
    try testing.expect(conn.extensions == null);
    try testing.expectEqual(@as(u64, 0), conn.bufferedAmount());
}

test "WebSocketConnection - invalid state operations" {
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "wss://example.com/socket");
    defer conn.deinit();

    // Cannot send while CONNECTING
    try testing.expectError(error.InvalidState, conn.sendText("Hello"));
    try testing.expectError(error.InvalidState, conn.sendBinary("binary"));
}

// =============================================================================
// The closing handshake and bufferedAmount, without a network
//
// WebSockets § 3.1 (close(), send(), bufferedAmount) and RFC 6455 § 5.5.1 and
// § 7. The connection holds this state; the interface only reads it.
// =============================================================================

const connection_mod = websocket.connection;

test "close payload: no code and no reason is an empty body" {
    // WebSockets § 3.1 close() step 3: "If neither code nor reason is present,
    // the WebSocket Close message must not have a body." This sent 1000.
    var buffer: [connection_mod.max_close_payload]u8 = undefined;
    try testing.expectEqual(@as(usize, 0), connection_mod.buildClosePayload(&buffer, null, null).len);
    try testing.expectEqualSlices(u8, &.{ 0x03, 0xE8 }, connection_mod.buildClosePayload(&buffer, 1000, null));
    try testing.expectEqualSlices(u8, &.{ 0x0B, 0xB8, 'b', 'y', 'e' }, connection_mod.buildClosePayload(&buffer, 3000, "bye"));
}

test "close payload: a received body gives the code and reason, or 1005's null" {
    const empty = try connection_mod.parseClosePayload("");
    try testing.expect(empty.code == null);
    const full = try connection_mod.parseClosePayload(&.{ 0x0F, 0xA0, 'o', 'k' });
    try testing.expectEqual(@as(?u16, 4000), full.code);
    try testing.expectEqualStrings("ok", full.reason);
    // One byte cannot hold a status code.
    try testing.expectError(error.ProtocolError, connection_mod.parseClosePayload(&.{0x03}));
}

test "outgoing queue: only application data counts, and a part-sent frame counts its rest" {
    var queue: connection_mod.OutgoingQueue = .{};
    defer queue.deinit(testing.allocator);

    try queue.push(testing.allocator, .text, "hello");
    try queue.push(testing.allocator, .close, &.{ 0x03, 0xE8 });
    try queue.push(testing.allocator, .binary, "abc");
    try testing.expectEqual(@as(u64, 8), queue.untransmitted);

    // Part of the head: the frame stays, and so does what is left of it.
    try testing.expect(queue.advance(testing.allocator, 2) == null);
    try testing.expectEqual(@as(u64, 6), queue.untransmitted);
    try testing.expectEqualStrings("llo", queue.head().?.remaining);

    // The rest of it, then the Close frame, which is not application data.
    try testing.expectEqual(@as(?websocket.curl_backend.FrameKind, .text), queue.advance(testing.allocator, 3));
    try testing.expectEqual(@as(u64, 3), queue.untransmitted);
    try testing.expectEqual(@as(?websocket.curl_backend.FrameKind, .close), queue.advance(testing.allocator, 2));
    try testing.expectEqual(@as(u64, 3), queue.untransmitted);
}

test "outgoing queue: dropping it twice is harmless" {
    // The connection drops its queue when the transport goes and again when
    // it is freed.
    var queue: connection_mod.OutgoingQueue = .{};
    try queue.push(testing.allocator, .text, "hello");
    queue.deinit(testing.allocator);
    queue.deinit(testing.allocator);
    try testing.expectEqual(@as(u64, 0), queue.untransmitted);
}

test "send before OPEN is discarded and still counted" {
    // § 3.1: bufferedAmount counts every send() that did not throw, and "will
    // only increase" once the connection is closing or closed.
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();
    conn.state = .CLOSING;

    try conn.send(.text, "hello");
    try conn.send(.binary, "abc");
    try testing.expectEqual(@as(u64, 8), conn.bufferedAmount());
    try testing.expect(conn.outgoing.head() == null);
}

test "close() while CONNECTING fails the connection and reads CLOSING" {
    // § 3.1 close() step 3: "Fail the WebSocket connection and set this's
    // ready state to CLOSING." The close task later reads CLOSED; failing is
    // never clean, reports 1006 and no reason, and fires `error` first.
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();

    try conn.close(3000, "asked for");
    try testing.expectEqual(websocket.ConnectionState.CLOSING, conn.state);
    try testing.expect(conn.closed);
    try testing.expect(conn.failed);
    try testing.expect(!conn.wasClean());
    try testing.expectEqual(@as(?u16, 1006), conn.close_code);
    try testing.expect(conn.close_reason == null);

    // A second close() does nothing.
    try conn.close(1000, null);
    try testing.expectEqual(@as(?u16, 1006), conn.close_code);
}

test "the peer's Close frame answers ours: closed cleanly, with the PEER's code and reason" {
    // RFC 6455 § 7.1.5-7.1.6: the connection close code and reason are those
    // of the first Close frame RECEIVED - not what close() asked for.
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();
    conn.state = .CLOSING;
    conn.close_queued = true;
    conn.close_sent = true;

    conn.handleCloseFrame(&.{ 0x0F, 0xA0, 'b', 'y', 'e' });
    try testing.expect(conn.closed);
    try testing.expect(!conn.failed);
    try testing.expect(conn.wasClean());
    try testing.expectEqual(@as(?u16, 4000), conn.close_code);
    try testing.expectEqualStrings("bye", conn.close_reason.?);
}

test "a Close frame with no body is reported as 1005" {
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();
    conn.state = .CLOSING;
    conn.close_queued = true;
    conn.close_sent = true;

    conn.handleCloseFrame("");
    try testing.expect(conn.closed);
    try testing.expectEqual(@as(?u16, 1005), conn.close_code);
    try testing.expect(conn.close_reason == null);
}

test "the peer starting the closing handshake moves OPEN to CLOSING and queues the echo" {
    // RFC 6455 § 5.5.1: answer a Close with a Close, echoing the status code.
    // Not closed yet: ours has not gone out (there is no socket here).
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();
    conn.state = .OPEN;

    conn.handleCloseFrame(&.{ 0x03, 0xE8 });
    try testing.expectEqual(websocket.ConnectionState.CLOSING, conn.state);
    try testing.expect(conn.close_queued);
    try testing.expect(!conn.closed);
    try testing.expectEqual(@as(?u16, 1000), conn.close_code);
    try testing.expectEqualSlices(u8, &.{ 0x03, 0xE8 }, conn.outgoing.head().?.remaining);

    // Application data after that is discarded, and counted.
    try conn.send(.text, "late");
    try testing.expectEqual(@as(u64, 4), conn.bufferedAmount());
}

test "a one-byte Close frame fails the connection" {
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://example.com/echo");
    defer conn.deinit();
    conn.state = .OPEN;

    conn.handleCloseFrame(&.{0x03});
    try testing.expect(conn.closed);
    try testing.expect(conn.failed);
    try testing.expectEqual(@as(?u16, 1006), conn.close_code);
}

// =============================================================================
// Reachability of the handshake path
//
// `connect` and everything it calls sat UNANALYSED until the WebSocket impl
// started calling them: nothing in this file, and nothing in `src/websocket/`,
// referenced `CurlWebSocket.connect`, so the compiler never looked inside it.
// It contained a call to `std.fmt.allocPrintZ`, removed in Zig 0.16, and
// `zig build test` stayed green over it for the whole migration - the exact
// shape of AGENTS.md's "a re-export does not mean the code is compiled".
//
// Referencing the functions is the test. Zig analyses what is REFERENCED, and
// `std.testing.refAllDecls` does not recurse into imported namespaces, so the
// reference has to be explicit and it has to live in a module that is wired
// into `zig build test`.
// =============================================================================

test "curl backend: the handshake and frame paths are analysed" {
    const CurlWebSocket = websocket.curl_backend.CurlWebSocket;

    _ = &CurlWebSocket.connect;
    _ = &CurlWebSocket.startConnect;
    _ = &CurlWebSocket.pollConnect;
    _ = &CurlWebSocket.sendPart;
    _ = &CurlWebSocket.receive;

    const Connection = websocket.WebSocketConnection;
    _ = &Connection.startConnect;
    _ = &Connection.pollConnect;
    _ = &Connection.flush;
    _ = &Connection.receive;
}

test "curl backend: a protocol list is joined with exactly N-1 commas" {
    // The join is sized exactly, and `deinit` frees it at that same length -
    // an over-reservation here is an allocator contract violation, not a leak,
    // and `std.testing.allocator` reports it as a size mismatch on free.
    const CurlWebSocket = websocket.curl_backend.CurlWebSocket;

    const two = try CurlWebSocket.init(
        testing.allocator,
        "ws://example.com/echo",
        &[_][]const u8{ "echo", "chat" },
    );
    defer two.deinit();
    try testing.expectEqualStrings("echo,chat", two.protocols.?);

    const one = try CurlWebSocket.init(
        testing.allocator,
        "ws://example.com/echo",
        &[_][]const u8{"echo"},
    );
    defer one.deinit();
    try testing.expectEqualStrings("echo", one.protocols.?);

    // No protocols at all must stay null: an empty Sec-WebSocket-Protocol
    // header is not the same request as no header.
    const none = try CurlWebSocket.init(testing.allocator, "ws://example.com/echo", null);
    defer none.deinit();
    try testing.expect(none.protocols == null);

    const empty = try CurlWebSocket.init(
        testing.allocator,
        "ws://example.com/echo",
        &[_][]const u8{},
    );
    defer empty.deinit();
    try testing.expect(empty.protocols == null);
}

test "startConnect: a handshake that fails on its first step frees everything once" {
    // startConnect sends the request at once, so a connection refused on the
    // spot (port 0, the first port websockets/Create-blocked-port.any.js
    // tries) fails inside it. It had already handed the easy handle, the multi
    // handle and the header list to the backend while its own errdefers were
    // still armed - so they freed all three, and failing the connection freed
    // them again: "pointer being freed was not allocated" in
    // curl_slist_free_all. Protocols and an origin make sure there IS a
    // header list.
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "ws://127.0.0.1:0/echo");
    defer conn.deinit();

    conn.startConnect(.{ .protocols = &.{ "echo", "chat" }, .origin = "http://example.com" }) catch {};
    while (!conn.closed) {
        _ = conn.pollConnect() catch break;
    }
    try testing.expect(conn.closed);
    try testing.expect(conn.failed);
    try testing.expect(conn.backend == null);
}

test "connect: a failed handshake frees the backend exactly once" {
    // `connect` takes the backend under an `errdefer` and then ALSO deinit'd it
    // in the failure branch, so every failed handshake freed it twice. Port 9
    // (discard) refuses a WebSocket upgrade, which is the ordinary case - a
    // blocked port, a refused connection, a bad host. Under
    // `std.testing.allocator` the second free is reported instead of being left
    // to corrupt the heap.
    var conn = try websocket.WebSocketConnection.init(
        testing.allocator,
        "ws://127.0.0.1:9/echo",
    );
    defer conn.deinit();

    try testing.expectError(error.HandshakeFailed, conn.connect(null));

    // "Fail the WebSocket connection": closed, failed, abnormal closure, and no
    // backend left for `deinit` to free a third time. The ready state stays
    // CONNECTING until the close task runs (WebSockets § 4).
    try testing.expect(conn.closed);
    try testing.expect(conn.failed);
    try testing.expectEqual(websocket.ConnectionState.CONNECTING, conn.state);
    try testing.expectEqual(
        @as(?u16, websocket.CloseCodes.ABNORMAL_CLOSURE),
        conn.close_code,
    );
    try testing.expect(conn.backend == null);
}
