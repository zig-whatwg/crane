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
//!   → structuredSerialize(data)
//!   → queue to outside_port
//!                                      inside_port receives
//!                                        → structuredDeserialize(data)
//!                                        → create MessageEvent
//!                                        → dispatch to WorkerGlobalScope
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import types from workers
const types = @import("types.zig");
const WorkerType = types.WorkerType;

// Structured clone types - when used in full module context, these come from html_core
// For standalone testing, we define minimal compatible types
pub const SerializedValue = struct {
    /// Serialization type
    type: SerializationType,

    /// Primitive value (if applicable)
    primitive: PrimitiveValue,

    /// Object map for object types
    object_map: ?*anyopaque,

    /// Array items for array types
    array_items: ?*anyopaque,

    /// Entries for Map/Set
    entries: ?*anyopaque,

    /// Additional properties
    properties: ?*anyopaque,

    /// Backing data (for typed arrays, etc.)
    backing_data: ?[]u8,

    /// Allocator
    allocator: Allocator,

    /// Error name (for Error objects)
    error_name: ?[]const u8,

    /// Error message (for Error objects)
    error_message: ?[]const u8,

    pub const SerializationType = enum {
        undefined,
        null,
        boolean,
        number,
        bigint,
        string,
        object,
        array,
        map,
        set,
        date,
        regexp,
        array_buffer,
        typed_array,
        error_obj,
    };

    pub const PrimitiveValue = union(enum) {
        undefined: void,
        null: void,
        boolean: bool,
        number: f64,
        bigint: i128,
        string: []const u8,
    };

    pub fn deinit(self: *SerializedValue) void {
        if (self.backing_data) |data| {
            self.allocator.free(data);
        }
        if (self.error_name) |name| {
            self.allocator.free(name);
        }
        if (self.error_message) |msg| {
            self.allocator.free(msg);
        }
    }
};

pub const JSValue = struct {
    value_type: ValueType,
    data: Data,

    pub const ValueType = enum {
        undefined,
        null,
        boolean,
        number,
        string,
        object,
        array,
    };

    pub const Data = union {
        undefined: void,
        null: void,
        boolean: bool,
        number: f64,
        string: []const u8,
        object: void,
        array: void,
    };
};

pub const CloneError = error{
    DataCloneError,
    TransferError,
    OutOfMemory,
};

// Stub implementations for structured clone
pub fn structuredSerialize(allocator: Allocator, value: *const JSValue) CloneError!*SerializedValue {
    _ = value;
    const serialized = allocator.create(SerializedValue) catch return CloneError.OutOfMemory;
    serialized.* = .{
        .type = .undefined,
        .primitive = .{ .undefined = {} },
        .object_map = null,
        .array_items = null,
        .entries = null,
        .properties = null,
        .backing_data = null,
        .allocator = allocator,
        .error_name = null,
        .error_message = null,
    };
    return serialized;
}

pub fn structuredDeserialize(allocator: Allocator, serialized: *SerializedValue) CloneError!*JSValue {
    _ = serialized;
    const value = allocator.create(JSValue) catch return CloneError.OutOfMemory;
    value.* = .{
        .value_type = .undefined,
        .data = .{ .undefined = {} },
    };
    return value;
}

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

    /// Serialized message data
    data: SerializedValue,

    /// Transferred objects (ports, streams, etc.)
    /// Each entry is an opaque pointer to a transferred object
    transferred: []?*anyopaque,

    pub fn init(allocator: Allocator) !*MessageData {
        const msg = try allocator.create(MessageData);
        msg.* = .{
            .allocator = allocator,
            .data = undefined, // Will be set by caller
            .transferred = &[_]?*anyopaque{},
        };
        return msg;
    }

    pub fn deinit(self: *MessageData) void {
        self.data.deinit();
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

    /// Post a message to the entangled port
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

    // Create dummy serialized value for testing
    var dummy_data = SerializedValue{
        .type = .undefined,
        .primitive = .{ .undefined = {} },
        .object_map = null,
        .array_items = null,
        .entries = null,
        .properties = null,
        .backing_data = null,
        .allocator = allocator,
        .error_name = null,
        .error_message = null,
    };

    // Try to post message - should fail
    const result = pair.outside_port.postMessage(&dummy_data, null);
    try std.testing.expectError(WorkerMessageError.PortClosed, result);
}
