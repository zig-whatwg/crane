//! MessagePort mock infrastructure for Streams transfer
//!
//! This is a minimal implementation of MessagePort sufficient for implementing
//! the WHATWG Streams transfer mechanism (§ 4.2.5 Transfer).
//!
//! Spec: HTML Standard §9.3 Message channels
//! https://html.spec.whatwg.org/#message-channels
//!
//! NOTE: This is a mock implementation for Streams-specific use.
//! A full HTML Standard MessagePort would require:
//! - EventTarget inheritance
//! - Full structured clone algorithm
//! - Worker/Window context integration
//! - Complete event loop integration

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const common = @import("common");
const JSValue = common.JSValue;

/// Message sent through a MessagePort
pub const Message = struct {
    /// Type of message: "chunk", "close", "error", or "pull"
    type: []const u8,

    /// Value associated with the message (may be undefined)
    value: JSValue,

    allocator: Allocator,

    pub fn init(allocator: Allocator, msg_type: []const u8, value: JSValue) !*Message {
        const msg = try allocator.create(Message);
        msg.* = .{
            .type = try allocator.dupe(u8, msg_type),
            .value = value,
            .allocator = allocator,
        };
        return msg;
    }

    pub fn deinit(self: *Message) void {
        self.allocator.free(self.type);
        self.allocator.destroy(self);
    }
};

/// Serialized message for cross-isolate delivery
/// Stores V8-serialized bytes that can be deserialized in any isolate
pub const SerializedMessage = struct {
    /// V8 serialized bytes
    data: []u8,

    allocator: Allocator,

    pub fn init(allocator: Allocator, data: []const u8) !*SerializedMessage {
        const msg = try allocator.create(SerializedMessage);
        msg.* = .{
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
        return msg;
    }

    pub fn deinit(self: *SerializedMessage) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }
};

/// MessagePort - mock implementation for Streams transfer
///
/// Spec: HTML Standard §9.3.2 Message ports
/// https://html.spec.whatwg.org/#message-ports
pub const MessagePort = struct {
    allocator: Allocator,

    /// Unique port ID
    id: u64,

    /// Entangled port (if any)
    entangled_port: ?*MessagePort,

    /// Message queue
    message_queue: infra.List(*Message),

    /// Cross-isolate serialized message queue
    /// Used when WebIDL entanglement is broken but internal entanglement exists
    /// (i.e., when a port is transferred to a worker)
    serialized_queue: infra.List(*SerializedMessage),

    /// Message handler (invoked when message received)
    onmessage: ?*const fn (*MessagePort, *Message) void,

    /// Message error handler
    onmessageerror: ?*const fn (*MessagePort) void,

    /// Whether the port is closed
    closed: bool,

    /// Whether the port's message queue is enabled
    /// Spec: § 9.3.2.2 "port message queue"
    queue_enabled: bool,

    /// Whether this port has been transferred to another isolate
    /// When true, the port should use cross-isolate messaging
    transferred: bool,

    /// Callback invoked when a serialized message is queued
    /// Used to trigger dispatch in the correct isolate context
    on_serialized_message: ?*const fn (*MessagePort) void,

    /// User data for the callback (typically the WebIDL wrapper)
    callback_user_data: ?*anyopaque,

    /// Flag indicating this port has pending cross-isolate messages
    /// Used to signal that the port's context should check for messages
    has_pending_cross_isolate: bool,

    pub fn init(allocator: Allocator) !*MessagePort {
        const port = try allocator.create(MessagePort);
        port.* = .{
            .allocator = allocator,
            .id = generatePortId(),
            .entangled_port = null,
            .message_queue = infra.List(*Message).init(allocator),
            .serialized_queue = infra.List(*SerializedMessage).init(allocator),
            .onmessage = null,
            .onmessageerror = null,
            .closed = false,
            .queue_enabled = false,
            .transferred = false,
            .on_serialized_message = null,
            .callback_user_data = null,
            .has_pending_cross_isolate = false,
        };
        return port;
    }

    pub fn deinit(self: *MessagePort) void {
        // Clean up message queue
        for (0..self.message_queue.len) |i| {
            if (self.message_queue.get(i)) |msg| {
                msg.deinit();
            }
        }
        self.message_queue.deinit();

        // Clean up serialized message queue
        for (0..self.serialized_queue.len) |i| {
            if (self.serialized_queue.get(i)) |msg| {
                msg.deinit();
            }
        }
        self.serialized_queue.deinit();

        // Disentangle if needed
        if (self.entangled_port) |other| {
            other.entangled_port = null;
        }

        self.allocator.destroy(self);
    }

    /// Entangle two ports
    /// Spec: § 9.3.2.3 "Entangle two message ports"
    pub fn entangle(port1: *MessagePort, port2: *MessagePort) void {
        port1.entangled_port = port2;
        port2.entangled_port = port1;
    }

    /// Disentangle a port from its entangled port
    /// Spec: § 9.3.2.4 "Disentangle a port"
    pub fn disentangle(self: *MessagePort) void {
        if (self.entangled_port) |other| {
            other.entangled_port = null;
            self.entangled_port = null;
        }
    }

    /// Post a message to the entangled port
    /// Spec: § 9.3.2.1 "postMessage(message, transfer)"
    ///
    /// For Streams transfer, we use simplified messages with type and value.
    pub fn postMessage(self: *MessagePort, msg_type: []const u8, value: JSValue) !void {
        if (self.closed) return error.PortClosed;
        if (self.entangled_port == null) return error.NotEntangled;

        const entangled = self.entangled_port.?;

        // Create message
        const msg = try Message.init(self.allocator, msg_type, value);
        errdefer msg.deinit();

        // Add to entangled port's queue
        try entangled.message_queue.append(msg);

        // If queue is enabled, dispatch immediately
        if (entangled.queue_enabled) {
            try entangled.dispatchQueuedMessages();
        }
    }

    /// Post a serialized message to the entangled port (for cross-isolate delivery)
    /// Used when WebIDL entanglement is broken but internal entanglement exists.
    /// The serialized bytes can be deserialized in any V8 isolate.
    pub fn postSerializedMessage(self: *MessagePort, data: []const u8) !void {
        if (self.closed) return error.PortClosed;
        if (self.entangled_port == null) return error.NotEntangled;

        const entangled = self.entangled_port.?;

        // Create serialized message
        const msg = try SerializedMessage.init(self.allocator, data);
        errdefer msg.deinit();

        // Add to entangled port's serialized queue
        try entangled.serialized_queue.append(msg);

        // Mark the port as having pending messages
        // The port's context will poll for this and dispatch
        entangled.has_pending_cross_isolate = true;

        // Notify the entangled port that a message is ready
        // This allows the port's owner to schedule dispatch on the correct event loop
        if (entangled.on_serialized_message) |callback| {
            callback(entangled);
        }
    }

    /// Check if there are pending serialized messages
    pub fn hasSerializedMessages(self: *MessagePort) bool {
        return self.serialized_queue.len > 0;
    }

    /// Get and remove the next serialized message from the queue
    pub fn popSerializedMessage(self: *MessagePort) ?*SerializedMessage {
        if (self.serialized_queue.len == 0) return null;
        const msg = self.serialized_queue.get(0) orelse return null;
        _ = self.serialized_queue.remove(0) catch return null;
        return msg;
    }

    /// Enable port's message queue
    /// Spec: § 9.3.2.2 "Enable port's message queue"
    pub fn enableQueue(self: *MessagePort) void {
        self.queue_enabled = true;
    }

    /// Dispatch all queued messages
    pub fn dispatchQueuedMessages(self: *MessagePort) !void {
        while (self.message_queue.len > 0) {
            const msg = self.message_queue.get(0) orelse continue;
            _ = try self.message_queue.remove(0);
            defer msg.deinit();

            if (self.onmessage) |handler| {
                handler(self, msg);
            }
        }
    }

    /// Close the port
    pub fn close(self: *MessagePort) void {
        self.closed = true;
        self.disentangle();
    }

    /// Generate unique port ID
    fn generatePortId() u64 {
        const S = struct {
            var counter: u64 = 0;
        };
        S.counter += 1;
        return S.counter;
    }
};

/// Create an entangled MessagePort pair
/// Spec: § 9.3.1 Message channels
///
/// Returns [port1, port2] where port1 and port2 are entangled.
pub fn createMessagePortPair(allocator: Allocator) ![2]*MessagePort {
    const port1 = try MessagePort.init(allocator);
    errdefer port1.deinit();

    const port2 = try MessagePort.init(allocator);
    errdefer port2.deinit();

    MessagePort.entangle(port1, port2);

    return .{ port1, port2 };
}

/// PackAndPostMessage helper
/// Spec: § 4.11.12 PackAndPostMessage
///
/// Simplified version for Streams cross-realm transforms.
pub fn packAndPostMessage(port: *MessagePort, msg_type: []const u8, value: JSValue) !void {
    try port.postMessage(msg_type, value);
}

/// PackAndPostMessageHandlingError helper
/// Spec: § 4.11.13 PackAndPostMessageHandlingError
///
/// Attempts to post a message, handling errors gracefully.
pub fn packAndPostMessageHandlingError(port: *MessagePort, msg_type: []const u8, value: JSValue) void {
    port.postMessage(msg_type, value) catch |err| {
        // In a full implementation, this would dispatch a messageerror event
        std.debug.print("Failed to post message: {}\n", .{err});
        if (port.onmessageerror) |handler| {
            handler(port);
        }
    };
}

/// CrossRealmTransformSendError helper
/// Spec: § 4.11.14 CrossRealmTransformSendError
///
/// Sends an error message through the port, handling failures.
pub fn crossRealmTransformSendError(port: *MessagePort, error_value: JSValue) void {
    packAndPostMessageHandlingError(port, "error", error_value);
}

// ============================================================================
// Tests
// ============================================================================
