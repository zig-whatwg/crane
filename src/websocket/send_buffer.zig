//! WebSocket Send Buffer and Message Queuing
//!
//! Implements the send buffer mechanism for the WebSocket API as per WHATWG spec.
//! The bufferedAmount attribute tracks queued data that hasn't been transmitted yet.
//!
//! ## WHATWG WebSocket Spec References
//!
//! - bufferedAmount: https://websockets.spec.whatwg.org/#dom-websocket-bufferedamount
//! - send() algorithm: https://websockets.spec.whatwg.org/#dom-websocket-send
//!
//! ## Buffer Behavior
//!
//! The spec defines bufferedAmount as:
//! "The number of bytes of application data (UTF-8 text and binary data) that have
//! been queued using send() but not yet been transmitted to the network."
//!
//! When send() is called:
//! 1. Data is added to the queue
//! 2. bufferedAmount increases by the data size
//! 3. Data is transmitted asynchronously
//! 4. bufferedAmount decreases as data is transmitted

const std = @import("std");

/// Message type for queued messages
pub const MessageType = enum {
    text,
    binary,
    close,
    ping,
    pong,
};

/// A queued message waiting to be sent
pub const QueuedMessage = struct {
    /// The message data
    data: []const u8,
    /// Type of message (text, binary, close, ping, pong)
    message_type: MessageType,
    /// Whether this message owns its data (should be freed on dequeue)
    owns_data: bool,
};

/// Send buffer for WebSocket messages.
/// Manages the queue of outgoing messages and tracks bufferedAmount.
pub const SendBuffer = struct {
    allocator: std.mem.Allocator,

    /// Queue of messages waiting to be sent
    queue: std.ArrayList(QueuedMessage),

    /// Total bytes of application data queued (UTF-8 text and binary)
    /// This is what the WebSocket.bufferedAmount attribute returns
    buffered_amount: u64,

    /// Maximum buffer size (0 = unlimited)
    max_buffer_size: u64,

    const Self = @This();

    /// Initialize a new send buffer.
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .queue = std.ArrayList(QueuedMessage).init(allocator),
            .buffered_amount = 0,
            .max_buffer_size = 0, // unlimited by default
        };
    }

    /// Initialize with a maximum buffer size.
    pub fn initWithLimit(allocator: std.mem.Allocator, max_size: u64) Self {
        return .{
            .allocator = allocator,
            .queue = std.ArrayList(QueuedMessage).init(allocator),
            .buffered_amount = 0,
            .max_buffer_size = max_size,
        };
    }

    /// Clean up the send buffer.
    pub fn deinit(self: *Self) void {
        // Free any owned data in queued messages
        for (self.queue.items) |msg| {
            if (msg.owns_data) {
                self.allocator.free(msg.data);
            }
        }
        self.queue.deinit();
    }

    /// Queue a text message for sending.
    /// Per WHATWG spec, text messages are UTF-8 encoded.
    ///
    /// Returns error.BufferFull if max_buffer_size would be exceeded.
    pub fn queueText(self: *Self, data: []const u8) !void {
        try self.queueMessage(data, .text, false);
    }

    /// Queue a text message, taking ownership of the data.
    pub fn queueTextOwned(self: *Self, data: []const u8) !void {
        try self.queueMessage(data, .text, true);
    }

    /// Queue a binary message for sending.
    ///
    /// Returns error.BufferFull if max_buffer_size would be exceeded.
    pub fn queueBinary(self: *Self, data: []const u8) !void {
        try self.queueMessage(data, .binary, false);
    }

    /// Queue a binary message, taking ownership of the data.
    pub fn queueBinaryOwned(self: *Self, data: []const u8) !void {
        try self.queueMessage(data, .binary, true);
    }

    /// Queue a close frame.
    /// Close frames don't count toward bufferedAmount per spec.
    pub fn queueClose(self: *Self, data: []const u8) !void {
        try self.queue.append(.{
            .data = data,
            .message_type = .close,
            .owns_data = false,
        });
        // Note: Close frames don't add to bufferedAmount
    }

    /// Queue a ping frame.
    /// Control frames don't count toward bufferedAmount.
    pub fn queuePing(self: *Self, data: []const u8) !void {
        try self.queue.append(.{
            .data = data,
            .message_type = .ping,
            .owns_data = false,
        });
    }

    /// Queue a pong frame.
    /// Control frames don't count toward bufferedAmount.
    pub fn queuePong(self: *Self, data: []const u8) !void {
        try self.queue.append(.{
            .data = data,
            .message_type = .pong,
            .owns_data = false,
        });
    }

    /// Internal: Queue a message with specified type.
    fn queueMessage(self: *Self, data: []const u8, msg_type: MessageType, owns_data: bool) !void {
        // Check buffer limit (only for application data: text and binary)
        if (msg_type == .text or msg_type == .binary) {
            if (self.max_buffer_size > 0) {
                if (self.buffered_amount + data.len > self.max_buffer_size) {
                    return error.BufferFull;
                }
            }
        }

        try self.queue.append(.{
            .data = data,
            .message_type = msg_type,
            .owns_data = owns_data,
        });

        // Update bufferedAmount for application data only
        if (msg_type == .text or msg_type == .binary) {
            self.buffered_amount += data.len;
        }
    }

    /// Dequeue the next message to send.
    /// Returns null if the queue is empty.
    pub fn dequeue(self: *Self) ?QueuedMessage {
        if (self.queue.items.len == 0) {
            return null;
        }

        const msg = self.queue.orderedRemove(0);

        // Update bufferedAmount for application data
        if (msg.message_type == .text or msg.message_type == .binary) {
            self.buffered_amount -= @min(msg.data.len, self.buffered_amount);
        }

        return msg;
    }

    /// Peek at the next message without removing it.
    pub fn peek(self: *const Self) ?QueuedMessage {
        if (self.queue.items.len == 0) {
            return null;
        }
        return self.queue.items[0];
    }

    /// Get the current bufferedAmount value.
    /// This is the total bytes of text and binary data queued.
    pub fn getBufferedAmount(self: *const Self) u64 {
        return self.buffered_amount;
    }

    /// Check if the buffer is empty.
    pub fn isEmpty(self: *const Self) bool {
        return self.queue.items.len == 0;
    }

    /// Get the number of queued messages.
    pub fn count(self: *const Self) usize {
        return self.queue.items.len;
    }

    /// Clear all queued messages.
    /// Frees owned data and resets bufferedAmount.
    pub fn clear(self: *Self) void {
        for (self.queue.items) |msg| {
            if (msg.owns_data) {
                self.allocator.free(msg.data);
            }
        }
        self.queue.clearRetainingCapacity();
        self.buffered_amount = 0;
    }

    /// Mark bytes as transmitted (decreases bufferedAmount).
    /// Used when partial transmission occurs.
    pub fn markTransmitted(self: *Self, bytes: u64) void {
        self.buffered_amount -= @min(bytes, self.buffered_amount);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "SendBuffer - init and deinit" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try std.testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
    try std.testing.expect(buffer.isEmpty());
}

test "SendBuffer - queue text message" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    const msg = "Hello, WebSocket!";
    try buffer.queueText(msg);

    try std.testing.expectEqual(@as(u64, msg.len), buffer.getBufferedAmount());
    try std.testing.expectEqual(@as(usize, 1), buffer.count());
    try std.testing.expect(!buffer.isEmpty());
}

test "SendBuffer - queue binary message" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    const data = &[_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05 };
    try buffer.queueBinary(data);

    try std.testing.expectEqual(@as(u64, 5), buffer.getBufferedAmount());
    try std.testing.expectEqual(@as(usize, 1), buffer.count());
}

test "SendBuffer - dequeue updates bufferedAmount" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try buffer.queueText("Hello");
    try buffer.queueText("World");

    try std.testing.expectEqual(@as(u64, 10), buffer.getBufferedAmount());

    const msg1 = buffer.dequeue();
    try std.testing.expect(msg1 != null);
    try std.testing.expectEqualStrings("Hello", msg1.?.data);
    try std.testing.expectEqual(@as(u64, 5), buffer.getBufferedAmount());

    const msg2 = buffer.dequeue();
    try std.testing.expect(msg2 != null);
    try std.testing.expectEqualStrings("World", msg2.?.data);
    try std.testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());

    try std.testing.expect(buffer.dequeue() == null);
}

test "SendBuffer - control frames don't affect bufferedAmount" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try buffer.queueText("data");
    try buffer.queuePing("");
    try buffer.queuePong("");
    try buffer.queueClose("");

    // Only text data counts
    try std.testing.expectEqual(@as(u64, 4), buffer.getBufferedAmount());
    try std.testing.expectEqual(@as(usize, 4), buffer.count());
}

test "SendBuffer - buffer limit" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.initWithLimit(allocator, 10);
    defer buffer.deinit();

    try buffer.queueText("12345");
    try std.testing.expectEqual(@as(u64, 5), buffer.getBufferedAmount());

    try buffer.queueText("12345");
    try std.testing.expectEqual(@as(u64, 10), buffer.getBufferedAmount());

    // Should fail - would exceed limit
    try std.testing.expectError(error.BufferFull, buffer.queueText("1"));
}

test "SendBuffer - peek doesn't remove" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try buffer.queueText("test");

    const peeked = buffer.peek();
    try std.testing.expect(peeked != null);
    try std.testing.expectEqualStrings("test", peeked.?.data);

    // Still in queue
    try std.testing.expectEqual(@as(usize, 1), buffer.count());
    try std.testing.expectEqual(@as(u64, 4), buffer.getBufferedAmount());
}

test "SendBuffer - clear" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try buffer.queueText("one");
    try buffer.queueText("two");
    try buffer.queueBinary("three");

    try std.testing.expectEqual(@as(usize, 3), buffer.count());

    buffer.clear();

    try std.testing.expect(buffer.isEmpty());
    try std.testing.expectEqual(@as(u64, 0), buffer.getBufferedAmount());
}

test "SendBuffer - message types" {
    const allocator = std.testing.allocator;
    var buffer = SendBuffer.init(allocator);
    defer buffer.deinit();

    try buffer.queueText("text");
    try buffer.queueBinary("binary");
    try buffer.queueClose("close");
    try buffer.queuePing("ping");
    try buffer.queuePong("pong");

    try std.testing.expectEqual(MessageType.text, buffer.dequeue().?.message_type);
    try std.testing.expectEqual(MessageType.binary, buffer.dequeue().?.message_type);
    try std.testing.expectEqual(MessageType.close, buffer.dequeue().?.message_type);
    try std.testing.expectEqual(MessageType.ping, buffer.dequeue().?.message_type);
    try std.testing.expectEqual(MessageType.pong, buffer.dequeue().?.message_type);
}
