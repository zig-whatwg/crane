//! Worker Message Channel - HTML Standard §10.2.3
//!
//! This module provides MessagePort pair creation and message passing
//! infrastructure for Web Workers.
//!
//! Spec: https://html.spec.whatwg.org/#message-ports
//!
//! ## Key Concepts
//!
//! - **MessagePort Pair**: Two entangled ports for bidirectional communication
//! - **postMessage**: Send message through structured clone to entangled port
//! - **MessageEvent**: Event dispatched when message is received
//!
//! ## Worker Message Flow
//!
//! ```
//! Main Thread                          Worker Thread
//! ─────────────                        ─────────────
//! worker.postMessage(data)
//!   → structuredSerializeWithTransfer(data)
//!   → queue to outside_port
//!                                      inside_port receives
//!                                        → structuredDeserializeWithTransfer(data)
//!                                        → create MessageEvent
//!                                        → dispatch to WorkerGlobalScope
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import types from workers
const types = @import("types.zig");
const WorkerType = types.WorkerType;

// Import the real structured clone implementation (direct import, avoiding circular dependency)
const structured_clone = @import("../structured_clone/root.zig");

// Re-export types from the real structured clone module
pub const SerializedValue = structured_clone.SerializedValue;
pub const JSValue = structured_clone.JSValue;
pub const CloneError = structured_clone.CloneError;
pub const Transferable = structured_clone.Transferable;
pub const TransferableArrayBuffer = structured_clone.TransferableArrayBuffer;
pub const TransferableMessagePort = structured_clone.TransferableMessagePort;
pub const SerializeWithTransferResult = structured_clone.SerializeWithTransferResult;
pub const DeserializeWithTransferResult = structured_clone.DeserializeWithTransferResult;

// Re-export the real structured clone functions
pub const structuredSerialize = structured_clone.structuredSerialize;
pub const structuredDeserialize = structured_clone.structuredDeserialize;
pub const structuredSerializeWithTransfer = structured_clone.structuredSerializeWithTransfer;
pub const structuredDeserializeWithTransfer = structured_clone.structuredDeserializeWithTransfer;
pub const structuredClone = structured_clone.structuredClone;
pub const freeJSValue = structured_clone.freeJSValue;

// ============================================================================
// Worker Message Error
// ============================================================================

pub const WorkerMessageError = error{
    /// Port is closed
    PortClosed,
    /// Ports not entangled
    NotEntangled,
    /// Data clone error
    DataCloneError,
    /// Out of memory
    OutOfMemory,
    /// Worker is closing
    WorkerClosing,
};

// ============================================================================
// Message Data
// ============================================================================

/// Message data after structured clone
pub const MessageData = struct {
    allocator: Allocator,

    /// Serialized message data (pointer to heap-allocated SerializedValue)
    data: *SerializedValue,

    /// Transferred objects (ports, streams, etc.)
    /// Each entry is an opaque pointer to a transferred object
    transferred: []?*anyopaque,

    pub fn init(allocator: Allocator, data: *SerializedValue) !*MessageData {
        const msg = try allocator.create(MessageData);
        msg.* = .{
            .allocator = allocator,
            .data = data,
            .transferred = &[_]?*anyopaque{},
        };
        return msg;
    }

    pub fn deinit(self: *MessageData) void {
        self.data.deinit();
        self.allocator.destroy(self.data);
        if (self.transferred.len > 0) {
            self.allocator.free(self.transferred);
        }
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Worker Port Pair
// ============================================================================

/// A pair of entangled ports for worker communication
///
/// Spec: HTML Standard §10.2.3
/// "Each Worker object has an associated outside port and inside port."
pub const WorkerPortPair = struct {
    allocator: Allocator,

    /// Port exposed to the owner (main thread or parent worker)
    outside_port: *WorkerPort,

    /// Port inside the worker (accessed via postMessage in worker)
    inside_port: *WorkerPort,

    /// Create a new entangled port pair for worker communication
    pub fn init(allocator: Allocator) !*WorkerPortPair {
        const pair = try allocator.create(WorkerPortPair);
        errdefer allocator.destroy(pair);

        // Create outside port
        const outside = try WorkerPort.init(allocator);
        errdefer outside.deinit();

        // Create inside port
        const inside = try WorkerPort.init(allocator);
        errdefer inside.deinit();

        // Entangle the ports
        outside.entangle(inside);

        pair.* = .{
            .allocator = allocator,
            .outside_port = outside,
            .inside_port = inside,
        };

        return pair;
    }

    pub fn deinit(self: *WorkerPortPair) void {
        self.outside_port.deinit();
        self.inside_port.deinit();
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Worker Port
// ============================================================================

/// A simplified MessagePort for worker communication
///
/// This wraps the core functionality needed for Worker.postMessage()
/// without the full EventTarget machinery.
pub const WorkerPort = struct {
    allocator: Allocator,

    /// Unique port ID
    id: u64,

    /// Entangled port
    entangled: ?*WorkerPort,

    /// Message queue (pending messages)
    message_queue: std.ArrayListUnmanaged(*QueuedMessage),

    /// Whether the port is closed
    closed: bool,

    /// Whether the queue is enabled (start() was called)
    queue_enabled: bool,

    /// Message handler callback
    on_message: ?*const fn (*WorkerPort, *QueuedMessage, ?*anyopaque) void,

    /// Context for message handler
    on_message_context: ?*anyopaque,

    var next_id: u64 = 1;

    pub fn init(allocator: Allocator) !*WorkerPort {
        const port = try allocator.create(WorkerPort);
        port.* = .{
            .allocator = allocator,
            .id = @atomicRmw(u64, &next_id, .Add, 1, .monotonic),
            .entangled = null,
            .message_queue = .{},
            .closed = false,
            .queue_enabled = false,
            .on_message = null,
            .on_message_context = null,
        };
        return port;
    }

    pub fn deinit(self: *WorkerPort) void {
        // Clean up queued messages
        for (self.message_queue.items) |msg| {
            msg.deinit();
        }
        self.message_queue.deinit(self.allocator);

        // Disentangle
        if (self.entangled) |other| {
            other.entangled = null;
        }

        self.allocator.destroy(self);
    }

    /// Entangle this port with another
    pub fn entangle(self: *WorkerPort, other: *WorkerPort) void {
        self.entangled = other;
        other.entangled = self;
    }

    /// Disentangle from paired port
    pub fn disentangle(self: *WorkerPort) void {
        if (self.entangled) |other| {
            other.entangled = null;
            self.entangled = null;
        }
    }

    /// Post a message to the entangled port (low-level, takes pre-serialized data)
    ///
    /// Spec: HTML Standard §10.2.3 postMessage()
    pub fn postMessage(self: *WorkerPort, data: *SerializedValue, transfer: ?[]?*anyopaque) WorkerMessageError!void {
        if (self.closed) {
            return WorkerMessageError.PortClosed;
        }

        const target = self.entangled orelse {
            return WorkerMessageError.NotEntangled;
        };

        // Create queued message
        const msg = QueuedMessage.init(self.allocator, data, transfer) catch {
            return WorkerMessageError.OutOfMemory;
        };
        errdefer msg.deinit();

        // Queue to target port
        target.message_queue.append(target.allocator, msg) catch {
            return WorkerMessageError.OutOfMemory;
        };

        // If target queue is enabled, dispatch immediately
        if (target.queue_enabled) {
            target.dispatchMessages();
        }
    }

    /// Post a JavaScript value to the entangled port (high-level, handles serialization)
    ///
    /// This is the main entry point for Worker.postMessage() - it:
    /// 1. Serializes the JSValue using structured clone
    /// 2. Queues the message to the entangled port
    /// 3. Dispatches immediately if the target queue is enabled
    ///
    /// Spec: HTML Standard §10.2.3 postMessage()
    /// "Let serializeWithTransferResult be StructuredSerializeWithTransfer(message, transfer)."
    pub fn postJSValue(self: *WorkerPort, value: *const JSValue, transfer_list: ?[]Transferable) WorkerMessageError!void {
        if (self.closed) {
            return WorkerMessageError.PortClosed;
        }

        const target = self.entangled orelse {
            return WorkerMessageError.NotEntangled;
        };

        // Serialize with transfer (if transfer list provided)
        const serialized = if (transfer_list) |transfers|
            structuredSerializeWithTransfer(self.allocator, value, transfers) catch |err| {
                return switch (err) {
                    error.DataCloneError => WorkerMessageError.DataCloneError,
                    error.TransferError => WorkerMessageError.DataCloneError,
                    error.OutOfMemory => WorkerMessageError.OutOfMemory,
                    else => WorkerMessageError.DataCloneError,
                };
            }
        else
            structuredSerialize(self.allocator, value) catch |err| {
                return switch (err) {
                    error.DataCloneError => WorkerMessageError.DataCloneError,
                    error.OutOfMemory => WorkerMessageError.OutOfMemory,
                    else => WorkerMessageError.DataCloneError,
                };
            };
        errdefer {
            var mutable_serialized = @constCast(serialized);
            mutable_serialized.deinit();
            self.allocator.destroy(mutable_serialized);
        }

        // Create queued message with the serialized data
        const msg = QueuedMessage.init(self.allocator, serialized, null) catch {
            return WorkerMessageError.OutOfMemory;
        };
        errdefer msg.deinit();

        // Queue to target port
        target.message_queue.append(target.allocator, msg) catch {
            return WorkerMessageError.OutOfMemory;
        };

        // If target queue is enabled, dispatch immediately
        if (target.queue_enabled) {
            target.dispatchMessages();
        }
    }

    /// Enable the port's message queue (start())
    ///
    /// Spec: HTML Standard §9.3.2 start()
    pub fn start(self: *WorkerPort) void {
        self.queue_enabled = true;
        self.dispatchMessages();
    }

    /// Close the port
    ///
    /// Spec: HTML Standard §9.3.2 close()
    pub fn close(self: *WorkerPort) void {
        self.closed = true;
        self.disentangle();
    }

    /// Set message handler
    pub fn setOnMessage(self: *WorkerPort, handler: *const fn (*WorkerPort, *QueuedMessage, ?*anyopaque) void, context: ?*anyopaque) void {
        self.on_message = handler;
        self.on_message_context = context;
    }

    /// Dispatch all queued messages
    fn dispatchMessages(self: *WorkerPort) void {
        while (self.message_queue.items.len > 0) {
            const msg = self.message_queue.orderedRemove(0);
            defer msg.deinit();

            if (self.on_message) |handler| {
                handler(self, msg, self.on_message_context);
            }
        }
    }
};

// ============================================================================
// Queued Message
// ============================================================================

/// A message queued for delivery
pub const QueuedMessage = struct {
    allocator: Allocator,

    /// Serialized message data
    data: *SerializedValue,

    /// Transferred objects
    transferred: ?[]?*anyopaque,

    /// Origin of the sender
    origin: ?[]const u8,

    pub fn init(allocator: Allocator, data: *SerializedValue, transfer: ?[]?*anyopaque) !*QueuedMessage {
        const msg = try allocator.create(QueuedMessage);
        msg.* = .{
            .allocator = allocator,
            .data = data,
            .transferred = transfer,
            .origin = null,
        };
        return msg;
    }

    pub fn deinit(self: *QueuedMessage) void {
        // Note: data is owned by caller, not freed here
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Serialize for postMessage
// ============================================================================

/// Serialize a value for postMessage
///
/// This wraps structured clone serialization for worker messaging.
pub fn serializeForPostMessage(allocator: Allocator, value: *const JSValue) WorkerMessageError!*SerializedValue {
    const serialized = structuredSerialize(allocator, value) catch |err| {
        return switch (err) {
            CloneError.DataCloneError => WorkerMessageError.DataCloneError,
            CloneError.OutOfMemory => WorkerMessageError.OutOfMemory,
            else => WorkerMessageError.DataCloneError,
        };
    };
    return serialized;
}

/// Deserialize a value from postMessage
///
/// This wraps structured clone deserialization for worker messaging.
pub fn deserializeFromPostMessage(allocator: Allocator, serialized: *SerializedValue) WorkerMessageError!*JSValue {
    const value = structuredDeserialize(allocator, serialized) catch |err| {
        return switch (err) {
            CloneError.OutOfMemory => WorkerMessageError.OutOfMemory,
            else => WorkerMessageError.DataCloneError,
        };
    };
    return value;
}

// ============================================================================
// Helper: Create Worker Ports
// ============================================================================

/// Create a port pair for a new worker
///
/// Returns the outside port (for the owner) and inside port (for the worker).
pub fn createWorkerPorts(allocator: Allocator) WorkerMessageError!*WorkerPortPair {
    return WorkerPortPair.init(allocator) catch {
        return WorkerMessageError.OutOfMemory;
    };
}

// ============================================================================
// Tests
// ============================================================================

test "WorkerPortPair - create and entangle" {
    const allocator = std.testing.allocator;

    const pair = try WorkerPortPair.init(allocator);
    defer pair.deinit();

    // Check ports are entangled
    try std.testing.expect(pair.outside_port.entangled == pair.inside_port);
    try std.testing.expect(pair.inside_port.entangled == pair.outside_port);
}

test "WorkerPort - close disentangles" {
    const allocator = std.testing.allocator;

    const pair = try WorkerPortPair.init(allocator);
    defer pair.deinit();

    // Close outside port
    pair.outside_port.close();

    // Both should be disentangled
    try std.testing.expect(pair.outside_port.entangled == null);
    try std.testing.expect(pair.inside_port.entangled == null);
}

test "WorkerPort - message after close fails" {
    const allocator = std.testing.allocator;

    const pair = try WorkerPortPair.init(allocator);
    defer pair.deinit();

    // Close outside port
    pair.outside_port.close();

    // Create dummy serialized value for testing (using proper structured clone format)
    var dummy_data = SerializedValue{
        .type = .primitive,
        .allocator = allocator,
        .data = .{ .primitive = .{ .undefined = {} } },
    };

    // Try to post message - should fail
    const result = pair.outside_port.postMessage(&dummy_data, null);
    try std.testing.expectError(WorkerMessageError.PortClosed, result);
}
