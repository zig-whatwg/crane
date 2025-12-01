//! Mock MessagePort for Service Workers
//!
//! TODO(html-spec): Replace this mock with real HTML MessagePort
//! when the HTML specification messaging section is implemented.
//! See: https://html.spec.whatwg.org/multipage/web-messaging.html#message-ports
//!
//! MessagePort enables communication between different execution contexts.
//! This mock provides basic message queuing for testing.
//!
//! WebIDL:
//! ```idl
//! [Exposed=(Window,Worker,AudioWorklet), Transferable]
//! interface MessagePort : EventTarget {
//!   undefined postMessage(any message, sequence<object> transfer);
//!   undefined postMessage(any message, optional StructuredSerializeOptions options = {});
//!   undefined start();
//!   undefined close();
//!
//!   // event handlers
//!   attribute EventHandler onclose;
//! };
//! MessagePort includes MessageEventTarget;
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Queued message for mock MessagePort.
pub const QueuedMessage = struct {
    /// Serialized message data (mock uses JSON or direct bytes).
    data: []const u8,

    /// Transfer list (not implemented in mock).
    transfer: []const *anyopaque,

    /// Origin of the sender.
    origin: []const u8,

    allocator: Allocator,

    pub fn deinit(self: *QueuedMessage) void {
        self.allocator.free(self.data);
        self.allocator.free(self.origin);
        self.allocator.free(self.transfer);
        self.allocator.destroy(self);
    }
};

/// Event handler function type.
pub const EventHandler = *const fn (data: []const u8, origin: []const u8) void;

/// Mock MessagePort interface.
///
/// Provides basic message passing functionality.
/// Messages are queued until start() is called.
pub const MessagePort = struct {
    allocator: Allocator,

    /// Whether the port is started (dispatching messages).
    started: bool = false,

    /// Whether the port is closed.
    closed: bool = false,

    /// Queue of pending messages.
    message_queue: std.ArrayList(*QueuedMessage),

    /// The entangled port (other end of the channel).
    entangled_port: ?*MessagePort = null,

    /// Event handlers (mock - in real impl these dispatch events).
    onmessage: ?EventHandler = null,
    onmessageerror: ?EventHandler = null,
    onclose: ?*const fn () void = null,

    /// Port identifier for debugging.
    id: u64,

    /// Counter for generating unique IDs.
    var next_id: u64 = 0;

    const Self = @This();

    /// Create a new MessagePort.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .message_queue = .{},
            .id = next_id,
        };
        next_id += 1;
        return self;
    }

    pub fn deinit(self: *Self) void {
        // Disentangle
        if (self.entangled_port) |other| {
            other.entangled_port = null;
        }

        // Clear message queue
        for (self.message_queue.items) |msg| {
            msg.deinit();
        }
        self.message_queue.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Post a message to the entangled port.
    ///
    /// Per spec:
    /// 1. If port is not entangled, do nothing
    /// 2. Serialize message (mock just copies bytes)
    /// 3. Create task to deliver message
    /// 4. Queue task on target port
    pub fn postMessage(self: *Self, data: []const u8) !void {
        try self.postMessageWithOrigin(data, "");
    }

    /// Post a message with explicit origin.
    pub fn postMessageWithOrigin(self: *Self, data: []const u8, origin: []const u8) !void {
        if (self.closed) return;

        const target = self.entangled_port orelse return;
        if (target.closed) return;

        // Create message
        const msg = try self.allocator.create(QueuedMessage);
        errdefer self.allocator.destroy(msg);

        msg.* = .{
            .data = try self.allocator.dupe(u8, data),
            .origin = try self.allocator.dupe(u8, origin),
            .transfer = try self.allocator.alloc(*anyopaque, 0),
            .allocator = self.allocator,
        };

        // Queue on target
        try target.message_queue.append(target.allocator, msg);

        // If target is started, dispatch immediately (mock behavior)
        if (target.started) {
            target.dispatchPendingMessages();
        }
    }

    /// Start the port, enabling message dispatch.
    ///
    /// Per spec:
    /// - Enables the port's message queue
    /// - Messages received before start() are queued
    /// - After start(), messages are dispatched immediately
    pub fn start(self: *Self) void {
        if (self.started or self.closed) return;
        self.started = true;

        // Dispatch any pending messages
        self.dispatchPendingMessages();
    }

    /// Close the port.
    ///
    /// Per spec:
    /// - Disentangles the port
    /// - Prevents further messages
    /// - Fires 'close' event on entangled port
    pub fn close(self: *Self) void {
        if (self.closed) return;
        self.closed = true;

        // Disentangle
        if (self.entangled_port) |other| {
            other.entangled_port = null;
            // Fire close event on other port
            if (other.onclose) |handler| {
                handler();
            }
        }
        self.entangled_port = null;

        // Fire own close event
        if (self.onclose) |handler| {
            handler();
        }
    }

    /// Dispatch pending messages (internal).
    fn dispatchPendingMessages(self: *Self) void {
        while (self.message_queue.items.len > 0) {
            const msg = self.message_queue.orderedRemove(0);
            defer msg.deinit();

            if (self.onmessage) |handler| {
                handler(msg.data, msg.origin);
            }
        }
    }

    // === Testing Helpers ===

    /// Get number of pending messages.
    pub fn getPendingMessageCount(self: *const Self) usize {
        return self.message_queue.items.len;
    }

    /// Check if port is entangled.
    pub fn isEntangled(self: *const Self) bool {
        return self.entangled_port != null;
    }

    /// Check if port is started.
    pub fn isStarted(self: *const Self) bool {
        return self.started;
    }

    /// Check if port is closed.
    pub fn isClosed(self: *const Self) bool {
        return self.closed;
    }
};

/// Mock MessageChannel - creates entangled port pair.
///
/// WebIDL:
/// ```idl
/// [Exposed=(Window,Worker)]
/// interface MessageChannel {
///   constructor();
///   readonly attribute MessagePort port1;
///   readonly attribute MessagePort port2;
/// };
/// ```
pub const MessageChannel = struct {
    allocator: Allocator,
    port1: *MessagePort,
    port2: *MessagePort,

    const Self = @This();

    /// Create a new MessageChannel with entangled ports.
    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const port1 = try MessagePort.init(allocator);
        errdefer port1.deinit();

        const port2 = try MessagePort.init(allocator);
        errdefer port2.deinit();

        // Entangle the ports
        port1.entangled_port = port2;
        port2.entangled_port = port1;

        self.* = .{
            .allocator = allocator,
            .port1 = port1,
            .port2 = port2,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.port1.deinit();
        self.port2.deinit();
        self.allocator.destroy(self);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "MessagePort.init creates port" {
    const allocator = std.testing.allocator;

    const port = try MessagePort.init(allocator);
    defer port.deinit();

    try std.testing.expect(!port.isStarted());
    try std.testing.expect(!port.isClosed());
    try std.testing.expect(!port.isEntangled());
}

test "MessageChannel creates entangled ports" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    try std.testing.expect(channel.port1.isEntangled());
    try std.testing.expect(channel.port2.isEntangled());
    try std.testing.expectEqual(channel.port2, channel.port1.entangled_port.?);
    try std.testing.expectEqual(channel.port1, channel.port2.entangled_port.?);
}

test "MessagePort.postMessage queues message on target" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    // Post message from port1 to port2
    try channel.port1.postMessage("hello");

    // Message should be queued on port2 (not started yet)
    try std.testing.expectEqual(@as(usize, 1), channel.port2.getPendingMessageCount());
    try std.testing.expectEqual(@as(usize, 0), channel.port1.getPendingMessageCount());
}

test "MessagePort.start dispatches pending messages" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    channel.port2.onmessage = struct {
        fn handler(data: []const u8, _: []const u8) void {
            _ = data;
            // In real test we'd capture this
        }
    }.handler;

    try channel.port1.postMessage("hello");
    try std.testing.expectEqual(@as(usize, 1), channel.port2.getPendingMessageCount());

    // Start port2 - should dispatch
    channel.port2.start();
    try std.testing.expectEqual(@as(usize, 0), channel.port2.getPendingMessageCount());
}

test "MessagePort.close disentangles ports" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    channel.port1.close();

    try std.testing.expect(channel.port1.isClosed());
    try std.testing.expect(!channel.port1.isEntangled());
    try std.testing.expect(!channel.port2.isEntangled());
}

test "MessagePort.postMessage after close does nothing" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    channel.port1.close();

    // Should not error, just do nothing
    try channel.port1.postMessage("hello");

    try std.testing.expectEqual(@as(usize, 0), channel.port2.getPendingMessageCount());
}

test "MessagePort started port dispatches immediately" {
    const allocator = std.testing.allocator;

    const channel = try MessageChannel.init(allocator);
    defer channel.deinit();

    // Start port2 first
    channel.port2.start();

    // Post message - should dispatch immediately
    try channel.port1.postMessage("hello");

    // No pending messages (dispatched immediately)
    try std.testing.expectEqual(@as(usize, 0), channel.port2.getPendingMessageCount());
}
