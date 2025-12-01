//! WebSocket Event Integration
//!
//! Provides event dispatching for WebSocket using the WHATWG-compliant task queue.
//! All WebSocket events are dispatched via "queue a task" per the spec:
//!
//! - open: When connection is established
//! - message: When a message is received
//! - error: When an error occurs
//! - close: When connection is closed
//!
//! ## Task Source
//!
//! Per WHATWG HTML spec, WebSocket events use the "networking" task source.
//! This ensures proper ordering with other network-related events.
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/#feedback-from-the-protocol
//! - WHATWG HTML Event Loops: https://html.spec.whatwg.org/multipage/webappapis.html#event-loops

const std = @import("std");

/// WebSocket event types
pub const WebSocketEventType = enum {
    open,
    message,
    @"error",
    close,
};

/// Data for 'open' event
pub const OpenEventData = struct {
    /// Negotiated extensions (comma-separated)
    extensions: ?[]const u8 = null,
    /// Negotiated subprotocol
    protocol: ?[]const u8 = null,
};

/// Data for 'message' event
pub const MessageEventData = struct {
    /// Message payload
    data: []const u8,
    /// True if text, false if binary
    is_text: bool,
    /// Origin URL
    origin: []const u8,
};

/// Data for 'close' event
pub const CloseEventData = struct {
    /// Whether connection closed cleanly
    was_clean: bool,
    /// Close code (1000-4999)
    code: u16,
    /// Close reason (max 123 bytes UTF-8)
    reason: []const u8,
};

/// WebSocket event union
pub const WebSocketEvent = union(WebSocketEventType) {
    open: OpenEventData,
    message: MessageEventData,
    @"error": void,
    close: CloseEventData,
};

/// WebSocket event task for queuing
pub const WebSocketEventTask = struct {
    allocator: std.mem.Allocator,

    /// The WebSocket instance pointer
    websocket_ptr: *anyopaque,

    /// The event to dispatch
    event: WebSocketEvent,

    /// Callback to dispatch the event (set by WebSocket impl)
    dispatch_callback: ?*const fn (websocket_ptr: *anyopaque, event: WebSocketEvent) void = null,

    const Self = @This();

    /// Create a new event task
    pub fn init(
        allocator: std.mem.Allocator,
        websocket_ptr: *anyopaque,
        event: WebSocketEvent,
    ) Self {
        return .{
            .allocator = allocator,
            .websocket_ptr = websocket_ptr,
            .event = event,
            .dispatch_callback = null,
        };
    }

    /// Execute the task (called by event loop)
    pub fn execute(self: *Self) void {
        if (self.dispatch_callback) |callback| {
            callback(self.websocket_ptr, self.event);
        }
    }

    /// Create an 'open' event task
    pub fn createOpen(
        allocator: std.mem.Allocator,
        websocket_ptr: *anyopaque,
        extensions: ?[]const u8,
        protocol: ?[]const u8,
    ) Self {
        return init(allocator, websocket_ptr, .{
            .open = .{
                .extensions = extensions,
                .protocol = protocol,
            },
        });
    }

    /// Create a 'message' event task
    pub fn createMessage(
        allocator: std.mem.Allocator,
        websocket_ptr: *anyopaque,
        data: []const u8,
        is_text: bool,
        origin: []const u8,
    ) Self {
        return init(allocator, websocket_ptr, .{
            .message = .{
                .data = data,
                .is_text = is_text,
                .origin = origin,
            },
        });
    }

    /// Create an 'error' event task
    pub fn createError(
        allocator: std.mem.Allocator,
        websocket_ptr: *anyopaque,
    ) Self {
        return init(allocator, websocket_ptr, .{ .@"error" = {} });
    }

    /// Create a 'close' event task
    pub fn createClose(
        allocator: std.mem.Allocator,
        websocket_ptr: *anyopaque,
        was_clean: bool,
        code: u16,
        reason: []const u8,
    ) Self {
        return init(allocator, websocket_ptr, .{
            .close = .{
                .was_clean = was_clean,
                .code = code,
                .reason = reason,
            },
        });
    }
};

/// Synchronous event dispatcher for when event loop is not available
/// This is a fallback for testing and simple use cases.
pub const SyncEventDispatcher = struct {
    /// Dispatch an event synchronously
    pub fn dispatch(task: *WebSocketEventTask) void {
        task.execute();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "WebSocketEventTask - create open event" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;

    const task = WebSocketEventTask.createOpen(
        allocator,
        &dummy,
        "permessage-deflate",
        "chat",
    );

    try std.testing.expect(task.event == .open);
    try std.testing.expectEqualStrings("permessage-deflate", task.event.open.extensions.?);
    try std.testing.expectEqualStrings("chat", task.event.open.protocol.?);
}

test "WebSocketEventTask - create message event" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;

    const task = WebSocketEventTask.createMessage(
        allocator,
        &dummy,
        "Hello, World!",
        true,
        "wss://example.com",
    );

    try std.testing.expect(task.event == .message);
    try std.testing.expectEqualStrings("Hello, World!", task.event.message.data);
    try std.testing.expect(task.event.message.is_text);
    try std.testing.expectEqualStrings("wss://example.com", task.event.message.origin);
}

test "WebSocketEventTask - create close event" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;

    const task = WebSocketEventTask.createClose(
        allocator,
        &dummy,
        true,
        1000,
        "Normal closure",
    );

    try std.testing.expect(task.event == .close);
    try std.testing.expect(task.event.close.was_clean);
    try std.testing.expectEqual(@as(u16, 1000), task.event.close.code);
    try std.testing.expectEqualStrings("Normal closure", task.event.close.reason);
}

test "WebSocketEventTask - create error event" {
    const allocator = std.testing.allocator;
    var dummy: u8 = 0;

    const task = WebSocketEventTask.createError(allocator, &dummy);

    try std.testing.expect(task.event == .@"error");
}

test "WebSocketEventTask - execute with callback" {
    const allocator = std.testing.allocator;

    const Context = struct {
        var event_received: ?WebSocketEvent = null;

        fn callback(_: *anyopaque, event: WebSocketEvent) void {
            event_received = event;
        }
    };

    var dummy: u8 = 0;
    var task = WebSocketEventTask.createOpen(allocator, &dummy, null, null);
    task.dispatch_callback = Context.callback;

    task.execute();

    try std.testing.expect(Context.event_received != null);
    try std.testing.expect(Context.event_received.? == .open);
}
