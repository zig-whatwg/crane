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

    /// Message queue (for internal streams messages)
    message_queue: infra.List(*Message),

    /// Pending WebIDL messages queue (for runtime.JSValue messages when queue is disabled)
    /// Stores heap-allocated pointers to runtime.JSValue (as *anyopaque)
    /// These are queued when postMessage is called but the queue is disabled
    pending_webidl_messages: infra.List(*anyopaque),

    /// Message handler (invoked when message received)
    onmessage: ?*const fn (*MessagePort, *Message) void,

    /// Message error handler
    onmessageerror: ?*const fn (*MessagePort) void,

    /// Whether the port is closed
    closed: bool,

    /// Whether the port's message queue is enabled
    /// Spec: § 9.3.2.2 "port message queue"
    queue_enabled: bool,

    /// Reference to WebIDL MessagePort instance for event dispatch
    /// This is a *runtime.Instance stored as *anyopaque to avoid circular dependencies
    webidl_instance: ?*anyopaque,

    pub fn init(allocator: Allocator) !*MessagePort {
        const port = try allocator.create(MessagePort);
        port.* = .{
            .allocator = allocator,
            .id = generatePortId(),
            .entangled_port = null,
            .message_queue = infra.List(*Message).init(allocator),
            .pending_webidl_messages = infra.List(*anyopaque).init(allocator),
            .onmessage = null,
            .onmessageerror = null,
            .closed = false,
            .queue_enabled = false,
            .webidl_instance = null,
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

        // Clean up pending WebIDL messages queue
        // Note: The actual runtime.JSValue cleanup is handled by the WebIDL layer
        // We just need to free the list itself
        self.pending_webidl_messages.deinit();

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

    /// Enable port's message queue
    /// Spec: § 9.3.2.2 "Enable port's message queue"
    pub fn enableQueue(self: *MessagePort) void {
        self.queue_enabled = true;
    }

    /// Queue a pending WebIDL message (for when queue is disabled)
    /// The msg_ptr should be a heap-allocated runtime.JSValue (as *anyopaque)
    /// Spec: § 9.4.1 step 11 - messages queue until port is enabled
    pub fn queuePendingMessage(self: *MessagePort, msg_ptr: *anyopaque) !void {
        try self.pending_webidl_messages.append(msg_ptr);
    }

    /// Pop a pending WebIDL message from the queue
    /// Returns null if the queue is empty
    /// The caller is responsible for casting back to *runtime.JSValue and cleaning up
    pub fn popPendingMessage(self: *MessagePort) ?*anyopaque {
        if (self.pending_webidl_messages.len == 0) return null;
        const msg_ptr = self.pending_webidl_messages.get(0) orelse return null;
        _ = self.pending_webidl_messages.remove(0) catch return null;
        return msg_ptr;
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
