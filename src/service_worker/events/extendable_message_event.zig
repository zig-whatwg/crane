//! ExtendableMessageEvent
//!
//! Event fired when a service worker receives a message.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#extendablemessageevent-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface ExtendableMessageEvent : ExtendableEvent {
//!   constructor(DOMString type, optional ExtendableMessageEventInit eventInitDict = {});
//!   readonly attribute any data;
//!   readonly attribute USVString origin;
//!   readonly attribute DOMString lastEventId;
//!   [SameObject] readonly attribute (Client or ServiceWorker or MessagePort)? source;
//!   readonly attribute FrozenArray<MessagePort> ports;
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const ExtendableEvent = @import("extendable_event.zig").ExtendableEvent;
const ExtendableEventInit = @import("extendable_event.zig").ExtendableEventInit;

/// Source type for ExtendableMessageEvent.
pub const MessageSource = union(enum) {
    /// Message from a Client.
    client: *anyopaque,

    /// Message from another ServiceWorker.
    service_worker: *anyopaque,

    /// Message from a MessagePort.
    message_port: *anyopaque,

    /// No source.
    none: void,
};

/// ExtendableMessageEvent initialization options.
pub const ExtendableMessageEventInit = struct {
    /// The message data.
    data: ?*anyopaque = null,

    /// Origin of the sender.
    origin: []const u8 = "",

    /// Last event ID (for EventSource).
    last_event_id: []const u8 = "",

    /// Message source (Client, ServiceWorker, or MessagePort).
    source: MessageSource = .none,

    /// Transferred MessagePorts.
    ports: []const *anyopaque = &[_]*anyopaque{},

    /// Base event options.
    event_init: ExtendableEventInit = .{},
};

/// ExtendableMessageEvent.
///
/// Fired when a service worker receives a message from a client,
/// another service worker, or a message port.
///
/// Spec: https://w3c.github.io/ServiceWorker/#extendablemessageevent-interface
pub const ExtendableMessageEvent = struct {
    allocator: Allocator,

    /// Base ExtendableEvent.
    base: *ExtendableEvent,
    owns_base: bool = false,

    /// The message data.
    data: ?*anyopaque = null,

    /// Origin of the sender.
    origin: []const u8,

    /// Last event ID (for EventSource compatibility).
    last_event_id: []const u8,

    /// Message source.
    source: MessageSource,

    /// Transferred MessagePorts.
    ports: []*anyopaque,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new ExtendableMessageEvent.
    pub fn init(allocator: Allocator, options: ExtendableMessageEventInit) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const base = try ExtendableEvent.init(allocator, "message", options.event_init);
        errdefer base.deinit();

        const origin_copy = try allocator.dupe(u8, options.origin);
        errdefer allocator.free(origin_copy);

        const last_event_id_copy = try allocator.dupe(u8, options.last_event_id);
        errdefer allocator.free(last_event_id_copy);

        // Copy ports array
        const ports_copy = try allocator.alloc(*anyopaque, options.ports.len);
        @memcpy(ports_copy, options.ports);

        self.* = .{
            .allocator = allocator,
            .base = base,
            .owns_base = true,
            .data = options.data,
            .origin = origin_copy,
            .last_event_id = last_event_id_copy,
            .source = options.source,
            .ports = ports_copy,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.origin);
        self.allocator.free(self.last_event_id);
        self.allocator.free(self.ports);

        if (self.owns_base) {
            self.base.deinit();
        }

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the message data.
    pub fn getData(self: *const Self) ?*anyopaque {
        return self.data;
    }

    /// Get the origin of the sender.
    pub fn getOrigin(self: *const Self) []const u8 {
        return self.origin;
    }

    /// Get the last event ID.
    pub fn getLastEventId(self: *const Self) []const u8 {
        return self.last_event_id;
    }

    /// Get the message source.
    pub fn getSource(self: *const Self) MessageSource {
        return self.source;
    }

    /// Get the transferred ports.
    pub fn getPorts(self: *const Self) []*anyopaque {
        return self.ports;
    }

    // =========================================================================
    // Delegated to ExtendableEvent
    // =========================================================================

    pub fn waitUntil(self: *Self) !u64 {
        return self.base.waitUntil();
    }

    pub fn resolvePromise(self: *Self, promise_id: u64) void {
        self.base.resolvePromise(promise_id);
    }

    pub fn rejectPromise(self: *Self, promise_id: u64, msg: ?[]const u8) void {
        self.base.rejectPromise(promise_id, msg);
    }

    pub fn startDispatch(self: *Self, target_ptr: *anyopaque) void {
        self.base.startDispatch(target_ptr);
    }

    pub fn endDispatch(self: *Self) void {
        self.base.endDispatch();
    }

    pub fn isComplete(self: *const Self) bool {
        return self.base.isComplete();
    }

    pub fn canExtend(self: *const Self) bool {
        return self.base.canExtend();
    }

    pub fn getType(self: *const Self) []const u8 {
        return self.base.getType();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ExtendableMessageEvent.init and deinit" {
    const allocator = std.testing.allocator;

    const event = try ExtendableMessageEvent.init(allocator, .{
        .origin = "https://example.com",
    });
    defer event.deinit();

    try std.testing.expectEqualStrings("message", event.getType());
    try std.testing.expectEqualStrings("https://example.com", event.getOrigin());
    try std.testing.expect(event.getData() == null);
}

test "ExtendableMessageEvent with data and source" {
    const allocator = std.testing.allocator;

    var dummy_data: u8 = 42;
    var dummy_client: u8 = 1;

    const event = try ExtendableMessageEvent.init(allocator, .{
        .data = &dummy_data,
        .origin = "https://example.com",
        .source = .{ .client = &dummy_client },
    });
    defer event.deinit();

    try std.testing.expect(event.getData() != null);
    try std.testing.expectEqualStrings("https://example.com", event.getOrigin());

    switch (event.getSource()) {
        .client => |c| try std.testing.expectEqual(&dummy_client, @as(*u8, @ptrCast(@alignCast(c)))),
        else => unreachable,
    }
}

test "ExtendableMessageEvent with ports" {
    const allocator = std.testing.allocator;

    var port1: u8 = 1;
    var port2: u8 = 2;
    const ports = [_]*anyopaque{ &port1, &port2 };

    const event = try ExtendableMessageEvent.init(allocator, .{
        .origin = "https://example.com",
        .ports = &ports,
    });
    defer event.deinit();

    try std.testing.expectEqual(@as(usize, 2), event.getPorts().len);
}

test "ExtendableMessageEvent.waitUntil" {
    const allocator = std.testing.allocator;

    const event = try ExtendableMessageEvent.init(allocator, .{
        .origin = "https://example.com",
    });
    defer event.deinit();

    const promise_id = try event.waitUntil();
    try std.testing.expect(!event.isComplete());

    event.resolvePromise(promise_id);
    try std.testing.expect(event.isComplete());
}

test "ExtendableMessageEvent.lastEventId" {
    const allocator = std.testing.allocator;

    const event = try ExtendableMessageEvent.init(allocator, .{
        .origin = "https://example.com",
        .last_event_id = "event-123",
    });
    defer event.deinit();

    try std.testing.expectEqualStrings("event-123", event.getLastEventId());
}
