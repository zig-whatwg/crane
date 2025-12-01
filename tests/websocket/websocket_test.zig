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
    try testing.expectEqual(@as(u16, 1007), websocket.CloseCodes.INVALID_PAYLOAD_DATA);
    try testing.expectEqual(@as(u16, 1008), websocket.CloseCodes.POLICY_VIOLATION);
    try testing.expectEqual(@as(u16, 1009), websocket.CloseCodes.MESSAGE_TOO_BIG);
    try testing.expectEqual(@as(u16, 1010), websocket.CloseCodes.MANDATORY_EXTENSION);
    try testing.expectEqual(@as(u16, 1011), websocket.CloseCodes.INTERNAL_ERROR);
    try testing.expectEqual(@as(u16, 1015), websocket.CloseCodes.TLS_HANDSHAKE_FAILURE);
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
    var buffer = websocket.SendBuffer.init(testing.allocator, 0);
    defer buffer.deinit();

    try testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
    try testing.expect(!buffer.hasMessages());
}

test "SendBuffer - queue text message" {
    var buffer = websocket.SendBuffer.init(testing.allocator, 0);
    defer buffer.deinit();

    try buffer.queueText("Hello, World!");

    try testing.expect(buffer.hasMessages());
    try testing.expectEqual(@as(u64, 13), buffer.getBufferedAmount());
}

test "SendBuffer - queue binary message" {
    var buffer = websocket.SendBuffer.init(testing.allocator, 0);
    defer buffer.deinit();

    const data = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    try buffer.queueBinary(&data);

    try testing.expect(buffer.hasMessages());
    try testing.expectEqual(@as(u64, 4), buffer.getBufferedAmount());
}

test "SendBuffer - dequeue preserves order" {
    var buffer = websocket.SendBuffer.init(testing.allocator, 0);
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

test "SendBuffer - markSent updates bufferedAmount" {
    var buffer = websocket.SendBuffer.init(testing.allocator, 0);
    defer buffer.deinit();

    try buffer.queueText("Hello"); // 5 bytes
    try testing.expectEqual(@as(u64, 5), buffer.getBufferedAmount());

    buffer.markSent(5);
    try testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
}

test "SendBuffer - max size limit" {
    var buffer = websocket.SendBuffer.init(testing.allocator, 10);
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
    try testing.expectEqual(@as(u64, 0), conn.buffered_amount);
}

test "WebSocketConnection - invalid state operations" {
    var conn = try websocket.WebSocketConnection.init(testing.allocator, "wss://example.com/socket");
    defer conn.deinit();

    // Cannot send while CONNECTING
    try testing.expectError(error.InvalidState, conn.sendText("Hello"));
    try testing.expectError(error.InvalidState, conn.sendBinary("binary"));
}
