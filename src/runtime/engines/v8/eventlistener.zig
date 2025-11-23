//! V8 EventListener Callback Management
//!
//! Manages EventListener callbacks for DOM events:
//! - addEventListener/removeEventListener integration
//! - Persistent function handles for callbacks
//! - Event dispatch and callback execution
//! - Listener lifecycle management
//!
//! Based on patterns from zig-js-runtime (Lightpanda headless browser).
//!
//! ## EventListener Lifecycle
//!
//! ```
//! 1. addEventListener("click", callback)
//!    → Create PersistentFunction for callback
//!    → Store in EventListenerRegistry
//!
//! 2. Event fires (click event)
//!    → Look up listeners for "click"
//!    → Call each callback with Event object
//!
//! 3. removeEventListener("click", callback)
//!    → Find PersistentFunction by callback ID
//!    → Remove from registry
//!    → Clear persistent handle
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const v8_eventlistener = @import("runtime").v8_eventlistener;
//!
//! // Create registry
//! var registry = v8_eventlistener.EventListenerRegistry.init(allocator);
//! defer registry.deinit();
//!
//! // Add listener
//! const listener_id = try registry.addEventListener(
//!     target_instance,
//!     "click",
//!     callback_func_handle,
//!     .{ .once = false, .capture = false }
//! );
//!
//! // Dispatch event
//! try registry.dispatchEvent(target_instance, "click", event_handle);
//!
//! // Remove listener
//! registry.removeEventListener(listener_id);
//! ```

const std = @import("std");
const v8_persistent = @import("persistent.zig");
const Instance = @import("../../instance.zig").Instance;

/// EventListener options
///
/// Options passed to addEventListener:
/// - capture: Use capturing phase instead of bubbling
/// - once: Automatically remove after first invocation
/// - passive: Handler won't call preventDefault()
pub const EventListenerOptions = struct {
    capture: bool = false,
    once: bool = false,
    passive: bool = false,
};

/// EventListener entry
///
/// Stores information about a registered event listener.
pub const EventListener = struct {
    id: u64,
    target: *Instance,
    event_type: []const u8,
    callback: *v8_persistent.PersistentFunction,
    options: EventListenerOptions,
    invocation_count: usize = 0,

    /// Check if listener should be removed after invocation
    pub fn shouldRemove(self: *const EventListener) bool {
        return self.options.once and self.invocation_count > 0;
    }
};

/// EventListener registry
///
/// Manages all event listeners for all targets.
/// Supports addEventListener, removeEventListener, and dispatchEvent.
pub const EventListenerRegistry = struct {
    allocator: std.mem.Allocator,
    listeners: std.ArrayList(EventListener),
    next_id: u64,

    /// Initialize registry
    pub fn init(allocator: std.mem.Allocator) EventListenerRegistry {
        return .{
            .allocator = allocator,
            .listeners = std.ArrayList(EventListener){},
            .next_id = 1,
        };
    }

    /// Deinitialize registry
    ///
    /// Clears all event listeners and frees resources.
    pub fn deinit(self: *EventListenerRegistry) void {
        for (self.listeners.items) |listener| {
            listener.callback.deinit();
            self.allocator.free(listener.event_type);
        }
        self.listeners.deinit(self.allocator);
    }

    /// Add event listener
    ///
    /// Registers a callback for the specified event type on the target.
    /// Returns listener ID for later removal.
    ///
    /// In real V8:
    /// ```c++
    /// target->addEventListener(event_type, callback, options);
    /// ```
    pub fn addEventListener(
        self: *EventListenerRegistry,
        target: *Instance,
        event_type: []const u8,
        callback_handle: usize,
        options: EventListenerOptions,
    ) !u64 {
        const listener_id = self.next_id;
        self.next_id += 1;

        // Create persistent function for callback
        const callback = try v8_persistent.PersistentFunction.init(
            self.allocator,
            callback_handle,
        );

        // Duplicate event_type string
        const event_type_copy = try self.allocator.dupe(u8, event_type);

        try self.listeners.append(.{
            .id = listener_id,
            .target = target,
            .event_type = event_type_copy,
            .callback = callback,
            .options = options,
        });

        return listener_id;
    }

    /// Remove event listener by ID
    ///
    /// In real V8:
    /// ```c++
    /// target->removeEventListener(event_type, callback);
    /// ```
    pub fn removeEventListener(self: *EventListenerRegistry, listener_id: u64) void {
        for (self.listeners.items, 0..) |listener, i| {
            if (listener.id == listener_id) {
                listener.callback.deinit();
                self.allocator.free(listener.event_type);
                _ = self.listeners.swapRemove(i);
                return;
            }
        }
    }

    /// Remove all event listeners for target
    ///
    /// Removes all listeners attached to the specified instance.
    pub fn removeAllListeners(self: *EventListenerRegistry, target: *const Instance) void {
        var i: usize = 0;
        while (i < self.listeners.items.len) {
            if (self.listeners.items[i].target == target) {
                const listener = self.listeners.swapRemove(i);
                listener.callback.deinit();
                self.allocator.free(listener.event_type);
            } else {
                i += 1;
            }
        }
    }

    /// Dispatch event to listeners
    ///
    /// Calls all registered listeners for the event type on the target.
    /// Handles 'once' option by removing single-use listeners after invocation.
    ///
    /// In real V8:
    /// ```c++
    /// Event event = new Event(event_type);
    /// for (listener : listeners) {
    ///     listener.callback(event);
    /// }
    /// ```
    pub fn dispatchEvent(
        self: *EventListenerRegistry,
        target: *const Instance,
        event_type: []const u8,
        event_handle: usize,
    ) !void {
        var to_remove = std.ArrayList(u64).init(self.allocator);
        defer to_remove.deinit();

        // Find and invoke matching listeners
        for (self.listeners.items) |*listener| {
            if (listener.target == target and
                std.mem.eql(u8, listener.event_type, event_type))
            {
                // Call listener callback
                const args = [_]usize{event_handle};
                _ = try listener.callback.call(null, &args);

                // Increment invocation count
                listener.invocation_count += 1;

                // Mark for removal if 'once' option
                if (listener.shouldRemove()) {
                    try to_remove.append(listener.id);
                }
            }
        }

        // Remove 'once' listeners
        for (to_remove.items) |listener_id| {
            self.removeEventListener(listener_id);
        }
    }

    /// Get listeners for target and event type
    ///
    /// Returns slice of all matching listeners.
    pub fn getListeners(
        self: *const EventListenerRegistry,
        allocator: std.mem.Allocator,
        target: *const Instance,
        event_type: []const u8,
    ) ![]const *const EventListener {
        var result = std.ArrayList(*const EventListener).init(allocator);

        for (self.listeners.items) |*listener| {
            if (listener.target == target and
                std.mem.eql(u8, listener.event_type, event_type))
            {
                try result.append(listener);
            }
        }

        return result.toOwnedSlice();
    }

    /// Get listener count for target
    pub fn getListenerCount(
        self: *const EventListenerRegistry,
        target: *const Instance,
    ) usize {
        var count: usize = 0;
        for (self.listeners.items) |listener| {
            if (listener.target == target) {
                count += 1;
            }
        }
        return count;
    }

    /// Get statistics
    pub fn getStats(self: *const EventListenerRegistry) Stats {
        var once_count: u32 = 0;
        var capture_count: u32 = 0;
        var passive_count: u32 = 0;

        for (self.listeners.items) |listener| {
            if (listener.options.once) once_count += 1;
            if (listener.options.capture) capture_count += 1;
            if (listener.options.passive) passive_count += 1;
        }

        return .{
            .total_listeners = @intCast(self.listeners.items.len),
            .once_listeners = once_count,
            .capture_listeners = capture_count,
            .passive_listeners = passive_count,
        };
    }

    pub const Stats = struct {
        total_listeners: u32,
        once_listeners: u32,
        capture_listeners: u32,
        passive_listeners: u32,
    };
};

// Unit tests

const testing = std.testing;

fn mockInstance() Instance {
    return .{
        .vtable = undefined,
        .state = null,
        .ctx = null,
    };
}

test "EventListenerRegistry init and deinit" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_listeners);
}

test "EventListenerRegistry addEventListener registers listener" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    const listener_id = try registry.addEventListener(
        &target,
        "click",
        0xDEADBEEF,
        .{ .once = false, .capture = false },
    );

    try testing.expect(listener_id > 0);

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.total_listeners);
}

test "EventListenerRegistry removeEventListener removes listener" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    const listener_id = try registry.addEventListener(
        &target,
        "click",
        0x12345678,
        .{},
    );

    registry.removeEventListener(listener_id);

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_listeners);
}

test "EventListenerRegistry dispatchEvent calls listeners" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(
        &target,
        "click",
        0x1111,
        .{},
    );

    // Should not error
    try registry.dispatchEvent(&target, "click", 0x2222);
}

test "EventListenerRegistry addEventListener with once option" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(
        &target,
        "click",
        0x3333,
        .{ .once = true },
    );

    var stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.once_listeners);

    // First dispatch should invoke and remove
    try registry.dispatchEvent(&target, "click", 0x4444);

    stats = registry.getStats();
    try testing.expectEqual(@as(u32, 0), stats.total_listeners);
}

test "EventListenerRegistry addEventListener with capture option" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(
        &target,
        "click",
        0x5555,
        .{ .capture = true },
    );

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.capture_listeners);
}

test "EventListenerRegistry addEventListener with passive option" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(
        &target,
        "click",
        0x6666,
        .{ .passive = true },
    );

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.passive_listeners);
}

test "EventListenerRegistry getListeners returns matching listeners" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(&target, "click", 0x1111, .{});
    _ = try registry.addEventListener(&target, "click", 0x2222, .{});
    _ = try registry.addEventListener(&target, "mouseover", 0x3333, .{});

    const listeners = try registry.getListeners(testing.allocator, &target, "click");
    defer testing.allocator.free(listeners);

    try testing.expectEqual(@as(usize, 2), listeners.len);
}

test "EventListenerRegistry removeAllListeners removes all for target" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target1 = mockInstance();
    var target2 = mockInstance();

    _ = try registry.addEventListener(&target1, "click", 0x1111, .{});
    _ = try registry.addEventListener(&target1, "mouseover", 0x2222, .{});
    _ = try registry.addEventListener(&target2, "click", 0x3333, .{});

    registry.removeAllListeners(&target1);

    const stats = registry.getStats();
    try testing.expectEqual(@as(u32, 1), stats.total_listeners);
}

test "EventListenerRegistry getListenerCount returns correct count" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(&target, "click", 0x1111, .{});
    _ = try registry.addEventListener(&target, "mouseover", 0x2222, .{});

    const count = registry.getListenerCount(&target);
    try testing.expectEqual(@as(usize, 2), count);
}

test "EventListener shouldRemove returns true only after invocation with once" {
    var registry = EventListenerRegistry.init(testing.allocator);
    defer registry.deinit();

    var target = mockInstance();

    _ = try registry.addEventListener(
        &target,
        "click",
        0x1111,
        .{ .once = true },
    );

    const listener = &registry.listeners.items[0];

    // Before invocation
    try testing.expect(!listener.shouldRemove());

    // After invocation
    listener.invocation_count = 1;
    try testing.expect(listener.shouldRemove());
}
