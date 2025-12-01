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
// Event Loop Integration
// =============================================================================

/// WebSocket event queue for integration with the WHATWG event loop.
///
/// Per WHATWG WebSockets spec, all WebSocket events must be dispatched via
/// "queue a task" using the WebSocket task source (part of networking).
///
/// ## Usage
///
/// ```zig
/// var queue = WebSocketEventQueue.init(allocator);
/// defer queue.deinit();
///
/// // Queue events
/// try queue.queueOpen(ws_ptr, "ext", "proto");
/// try queue.queueMessage(ws_ptr, "hello", true, "ws://example.com");
/// try queue.queueClose(ws_ptr, true, 1000, "Normal");
///
/// // Process events (called by event loop)
/// while (queue.dequeue()) |task| {
///     task.execute();
///     // cleanup task
/// }
/// ```
pub const WebSocketEventQueue = struct {
    allocator: std.mem.Allocator,

    /// Queue of pending tasks
    tasks: std.ArrayList(*WebSocketEventTask),

    /// Dispatch callback (shared across all tasks)
    dispatch_callback: ?*const fn (websocket_ptr: *anyopaque, event: WebSocketEvent) void = null,

    const Self = @This();

    /// Initialize the event queue
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .tasks = std.ArrayList(*WebSocketEventTask).init(allocator),
            .dispatch_callback = null,
        };
    }

    /// Deinitialize the event queue
    pub fn deinit(self: *Self) void {
        // Free any remaining tasks
        for (self.tasks.items) |task| {
            self.allocator.destroy(task);
        }
        self.tasks.deinit();
    }

    /// Set the dispatch callback for all events
    pub fn setDispatchCallback(
        self: *Self,
        callback: *const fn (websocket_ptr: *anyopaque, event: WebSocketEvent) void,
    ) void {
        self.dispatch_callback = callback;
    }

    /// Queue an 'open' event
    pub fn queueOpen(
        self: *Self,
        websocket_ptr: *anyopaque,
        extensions: ?[]const u8,
        protocol: ?[]const u8,
    ) !void {
        const task = try self.allocator.create(WebSocketEventTask);
        task.* = WebSocketEventTask.createOpen(self.allocator, websocket_ptr, extensions, protocol);
        task.dispatch_callback = self.dispatch_callback;
        try self.tasks.append(task);
    }

    /// Queue a 'message' event
    pub fn queueMessage(
        self: *Self,
        websocket_ptr: *anyopaque,
        data: []const u8,
        is_text: bool,
        origin: []const u8,
    ) !void {
        const task = try self.allocator.create(WebSocketEventTask);
        task.* = WebSocketEventTask.createMessage(self.allocator, websocket_ptr, data, is_text, origin);
        task.dispatch_callback = self.dispatch_callback;
        try self.tasks.append(task);
    }

    /// Queue an 'error' event
    pub fn queueError(self: *Self, websocket_ptr: *anyopaque) !void {
        const task = try self.allocator.create(WebSocketEventTask);
        task.* = WebSocketEventTask.createError(self.allocator, websocket_ptr);
        task.dispatch_callback = self.dispatch_callback;
        try self.tasks.append(task);
    }

    /// Queue a 'close' event
    pub fn queueClose(
        self: *Self,
        websocket_ptr: *anyopaque,
        was_clean: bool,
        code: u16,
        reason: []const u8,
    ) !void {
        const task = try self.allocator.create(WebSocketEventTask);
        task.* = WebSocketEventTask.createClose(self.allocator, websocket_ptr, was_clean, code, reason);
        task.dispatch_callback = self.dispatch_callback;
        try self.tasks.append(task);
    }

    /// Dequeue the next event task (FIFO order)
    /// Returns null if queue is empty
    pub fn dequeue(self: *Self) ?*WebSocketEventTask {
        if (self.tasks.items.len == 0) return null;
        return self.tasks.orderedRemove(0);
    }

    /// Check if the queue is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.tasks.items.len == 0;
    }

    /// Get the number of pending tasks
    pub fn pendingCount(self: *const Self) usize {
        return self.tasks.items.len;
    }

    /// Process all pending events synchronously
    /// This is a convenience method for testing and simple use cases.
    pub fn processAll(self: *Self) void {
        while (self.dequeue()) |task| {
            task.execute();
            self.allocator.destroy(task);
        }
    }
};

/// Task source identifier for WebSocket events
/// Per WHATWG HTML spec, WebSocket uses the "WebSocket task source"
/// which is part of the networking task queue.
pub const WEBSOCKET_TASK_SOURCE = "websocket";

/// WebSocket event loop adapter
///
/// Integrates WebSocketEventQueue with the WHATWG event loop task queue.
/// This adapter converts WebSocket events to TaskNode format for the
/// priority-based event loop.
pub const WebSocketEventLoopAdapter = struct {
    allocator: std.mem.Allocator,

    /// The underlying event queue
    event_queue: WebSocketEventQueue,

    const Self = @This();

    /// Initialize the adapter
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .event_queue = WebSocketEventQueue.init(allocator),
        };
    }

    /// Deinitialize the adapter
    pub fn deinit(self: *Self) void {
        self.event_queue.deinit();
    }

    /// Set the dispatch callback
    pub fn setDispatchCallback(
        self: *Self,
        callback: *const fn (websocket_ptr: *anyopaque, event: WebSocketEvent) void,
    ) void {
        self.event_queue.setDispatchCallback(callback);
    }

    /// Queue an open event
    pub fn queueOpen(
        self: *Self,
        websocket_ptr: *anyopaque,
        extensions: ?[]const u8,
        protocol: ?[]const u8,
    ) !void {
        try self.event_queue.queueOpen(websocket_ptr, extensions, protocol);
    }

    /// Queue a message event
    pub fn queueMessage(
        self: *Self,
        websocket_ptr: *anyopaque,
        data: []const u8,
        is_text: bool,
        origin: []const u8,
    ) !void {
        try self.event_queue.queueMessage(websocket_ptr, data, is_text, origin);
    }

    /// Queue an error event
    pub fn queueError(self: *Self, websocket_ptr: *anyopaque) !void {
        try self.event_queue.queueError(websocket_ptr);
    }

    /// Queue a close event
    pub fn queueClose(
        self: *Self,
        websocket_ptr: *anyopaque,
        was_clean: bool,
        code: u16,
        reason: []const u8,
    ) !void {
        try self.event_queue.queueClose(websocket_ptr, was_clean, code, reason);
    }

    /// Check if there are pending events
    pub fn hasPendingEvents(self: *const Self) bool {
        return !self.event_queue.isEmpty();
    }

    /// Get the number of pending events
    pub fn pendingCount(self: *const Self) usize {
        return self.event_queue.pendingCount();
    }

    /// Process the next event
    /// Returns true if an event was processed, false if queue was empty
    pub fn processNext(self: *Self) bool {
        if (self.event_queue.dequeue()) |task| {
            task.execute();
            self.allocator.destroy(task);
            return true;
        }
        return false;
    }

    /// Process all pending events
    pub fn processAll(self: *Self) void {
        self.event_queue.processAll();
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

test "WebSocketEventQueue - basic operations" {
    const allocator = std.testing.allocator;

    var queue = WebSocketEventQueue.init(allocator);
    defer queue.deinit();

    var dummy: u8 = 0;

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), queue.pendingCount());

    // Queue events
    try queue.queueOpen(&dummy, "ext1", "proto1");
    try queue.queueMessage(&dummy, "hello", true, "ws://localhost");
    try queue.queueClose(&dummy, true, 1000, "goodbye");

    try std.testing.expect(!queue.isEmpty());
    try std.testing.expectEqual(@as(usize, 3), queue.pendingCount());

    // Dequeue in FIFO order
    const task1 = queue.dequeue().?;
    defer allocator.destroy(task1);
    try std.testing.expect(task1.event == .open);

    const task2 = queue.dequeue().?;
    defer allocator.destroy(task2);
    try std.testing.expect(task2.event == .message);

    const task3 = queue.dequeue().?;
    defer allocator.destroy(task3);
    try std.testing.expect(task3.event == .close);

    try std.testing.expect(queue.isEmpty());
    try std.testing.expectEqual(@as(?*WebSocketEventTask, null), queue.dequeue());
}

test "WebSocketEventQueue - dispatch callback" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        var events_received: usize = 0;
        var last_event_type: ?WebSocketEventType = null;

        fn dispatch(_: *anyopaque, event: WebSocketEvent) void {
            events_received += 1;
            last_event_type = std.meta.activeTag(event);
        }
    };

    TestContext.events_received = 0;
    TestContext.last_event_type = null;

    var queue = WebSocketEventQueue.init(allocator);
    defer queue.deinit();

    queue.setDispatchCallback(TestContext.dispatch);

    var dummy: u8 = 0;
    try queue.queueOpen(&dummy, null, null);
    try queue.queueMessage(&dummy, "test", true, "ws://test");

    queue.processAll();

    try std.testing.expectEqual(@as(usize, 2), TestContext.events_received);
    try std.testing.expectEqual(WebSocketEventType.message, TestContext.last_event_type.?);
}

test "WebSocketEventLoopAdapter - event ordering" {
    const allocator = std.testing.allocator;

    const TestContext = struct {
        var event_order: [4]WebSocketEventType = undefined;
        var event_index: usize = 0;

        fn dispatch(_: *anyopaque, event: WebSocketEvent) void {
            if (event_index < 4) {
                event_order[event_index] = std.meta.activeTag(event);
                event_index += 1;
            }
        }
    };

    TestContext.event_index = 0;

    var adapter = WebSocketEventLoopAdapter.init(allocator);
    defer adapter.deinit();

    adapter.setDispatchCallback(TestContext.dispatch);

    var dummy: u8 = 0;

    // Queue events in expected order: open, message, message, close
    try adapter.queueOpen(&dummy, null, null);
    try adapter.queueMessage(&dummy, "msg1", true, "ws://test");
    try adapter.queueMessage(&dummy, "msg2", true, "ws://test");
    try adapter.queueClose(&dummy, true, 1000, "");

    try std.testing.expectEqual(@as(usize, 4), adapter.pendingCount());

    // Process all events
    adapter.processAll();

    try std.testing.expectEqual(@as(usize, 0), adapter.pendingCount());
    try std.testing.expectEqual(@as(usize, 4), TestContext.event_index);

    // Verify order: open fires before messages, close fires last
    try std.testing.expectEqual(WebSocketEventType.open, TestContext.event_order[0]);
    try std.testing.expectEqual(WebSocketEventType.message, TestContext.event_order[1]);
    try std.testing.expectEqual(WebSocketEventType.message, TestContext.event_order[2]);
    try std.testing.expectEqual(WebSocketEventType.close, TestContext.event_order[3]);
}

test "WebSocketEventLoopAdapter - processNext" {
    const allocator = std.testing.allocator;

    var adapter = WebSocketEventLoopAdapter.init(allocator);
    defer adapter.deinit();

    var dummy: u8 = 0;

    // Empty queue returns false
    try std.testing.expect(!adapter.processNext());

    try adapter.queueOpen(&dummy, null, null);
    try adapter.queueClose(&dummy, false, 1006, "abnormal");

    // Process one at a time
    try std.testing.expect(adapter.processNext());
    try std.testing.expectEqual(@as(usize, 1), adapter.pendingCount());

    try std.testing.expect(adapter.processNext());
    try std.testing.expectEqual(@as(usize, 0), adapter.pendingCount());

    try std.testing.expect(!adapter.processNext());
}
