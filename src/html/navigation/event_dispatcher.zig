//! Navigation Event DOM Dispatcher - HTML Standard §7.2.7
//!
//! This module provides the interface for dispatching navigation events to the DOM.
//! It defines the event structures and dispatch callbacks needed by navigation algorithms
//! to fire events like popstate, hashchange, beforeunload, etc.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html
//!
//! ## Architecture
//!
//! Navigation events are fired from algorithms.zig and other navigation code.
//! This module provides:
//! 1. Event data structures (matching the DOM Event interfaces)
//! 2. A dispatcher interface that can be implemented by the DOM layer
//! 3. Convenience functions for firing events
//!
//! The actual DOM Event creation and dispatch happens at a higher level
//! (in the full html module or webidl impls) to avoid circular dependencies.
//!
//! ## Usage
//!
//! ```zig
//! // Set up a dispatcher (typically done once at initialization)
//! const dispatcher = NavigationEventDispatcher.init(allocator, .{
//!     .fire_popstate = myPopStateHandler,
//!     .fire_hashchange = myHashChangeHandler,
//!     .fire_beforeunload = myBeforeUnloadHandler,
//! });
//!
//! // From navigation algorithm:
//! try dispatcher.firePopState(window_id, state, false);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

// Import the event types from the local events module
const events = @import("events.zig");
const SerializedState = @import("session_history.zig").SerializedState;

/// DOM Event phase constants (from DOM spec §2.3)
pub const EventPhase = struct {
    pub const NONE: u16 = 0;
    pub const CAPTURING_PHASE: u16 = 1;
    pub const AT_TARGET: u16 = 2;
    pub const BUBBLING_PHASE: u16 = 3;
};

/// PopStateEvent data for dispatch
/// Contains the data needed to create and fire a PopStateEvent
pub const PopStateEventData = struct {
    /// The serialized state from the history entry
    state: ?SerializedState,
    /// Whether the UA performed a visual transition
    has_ua_visual_transition: bool,
    /// Whether the event is trusted (fired by UA)
    is_trusted: bool = true,

    pub const event_type: []const u8 = "popstate";
    pub const bubbles: bool = true;
    pub const cancelable: bool = false;
};

/// HashChangeEvent data for dispatch
/// Contains the data needed to create and fire a HashChangeEvent
pub const HashChangeEventData = struct {
    /// The previous URL (including fragment)
    old_url: []const u8,
    /// The new URL (including fragment)
    new_url: []const u8,
    /// Whether the event is trusted (fired by UA)
    is_trusted: bool = true,

    pub const event_type: []const u8 = "hashchange";
    pub const bubbles: bool = true;
    pub const cancelable: bool = false;
};

/// BeforeUnloadEvent data for dispatch
/// Contains the data needed to create and fire a BeforeUnloadEvent
pub const BeforeUnloadEventData = struct {
    /// Whether the event is trusted (fired by UA)
    is_trusted: bool = true,

    pub const event_type: []const u8 = "beforeunload";
    pub const bubbles: bool = true;
    pub const cancelable: bool = true;
};

/// PageTransitionEvent data for dispatch
/// Contains the data needed to create and fire a pagehide or pageshow event
pub const PageTransitionEventData = struct {
    /// "pageshow" or "pagehide"
    event_type: []const u8,
    /// For pageshow: true if from bfcache; for pagehide: true if might be reused
    persisted: bool,
    /// Whether the event is trusted (fired by UA)
    is_trusted: bool = true,

    pub const bubbles: bool = true;
    pub const cancelable: bool = true; // Historical reasons
};

/// Unload event data for dispatch
pub const UnloadEventData = struct {
    /// Whether the event is trusted (fired by UA)
    is_trusted: bool = true,

    pub const event_type: []const u8 = "unload";
    pub const bubbles: bool = false;
    pub const cancelable: bool = false;
};

/// Window identifier for event dispatch
/// Can be an opaque pointer, ID, or other reference to a Window object
pub const WindowId = *anyopaque;

/// Callback function types for event dispatch
pub const FirePopStateFn = *const fn (allocator: Allocator, window_id: WindowId, data: PopStateEventData) anyerror!void;
pub const FireHashChangeFn = *const fn (allocator: Allocator, window_id: WindowId, data: HashChangeEventData) anyerror!void;
pub const FireBeforeUnloadFn = *const fn (allocator: Allocator, window_id: WindowId, data: BeforeUnloadEventData) anyerror!bool;
pub const FirePageTransitionFn = *const fn (allocator: Allocator, window_id: WindowId, data: PageTransitionEventData) anyerror!void;
pub const FireUnloadFn = *const fn (allocator: Allocator, window_id: WindowId, data: UnloadEventData) anyerror!void;

/// Dispatch callbacks configuration
pub const DispatchCallbacks = struct {
    fire_popstate: ?FirePopStateFn = null,
    fire_hashchange: ?FireHashChangeFn = null,
    fire_beforeunload: ?FireBeforeUnloadFn = null,
    fire_page_transition: ?FirePageTransitionFn = null,
    fire_unload: ?FireUnloadFn = null,
};

/// Navigation Event Dispatcher
///
/// Provides methods to fire navigation events. The actual DOM event creation
/// and dispatch is handled by the callbacks, allowing this module to be used
/// without direct dependency on the DOM/WebIDL impl layer.
pub const NavigationEventDispatcher = struct {
    allocator: Allocator,
    callbacks: DispatchCallbacks,

    /// Global dispatcher instance (set by the integration layer)
    var global_instance: ?*NavigationEventDispatcher = null;

    pub fn init(allocator: Allocator, callbacks: DispatchCallbacks) NavigationEventDispatcher {
        return .{
            .allocator = allocator,
            .callbacks = callbacks,
        };
    }

    /// Set the global dispatcher instance
    pub fn setGlobal(instance: *NavigationEventDispatcher) void {
        global_instance = instance;
    }

    /// Get the global dispatcher instance
    pub fn getGlobal() ?*NavigationEventDispatcher {
        return global_instance;
    }

    /// Fire a popstate event on the Window object
    ///
    /// HTML Standard §7.2.7.2:
    /// "The popstate event is fired at the Window when the active history entry changes
    /// while the document is the same."
    pub fn firePopState(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
        state: ?SerializedState,
        has_ua_visual_transition: bool,
    ) !void {
        if (self.callbacks.fire_popstate) |fire_fn| {
            try fire_fn(self.allocator, window_id, .{
                .state = state,
                .has_ua_visual_transition = has_ua_visual_transition,
            });
        }
        // If no callback is set, the event is silently dropped
        // This allows navigation algorithms to work without full DOM integration
    }

    /// Fire a hashchange event on the Window object
    ///
    /// HTML Standard §7.2.7.3:
    /// "The hashchange event is fired at the Window when the fragment part of
    /// the URL changes."
    pub fn fireHashChange(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
        old_url: []const u8,
        new_url: []const u8,
    ) !void {
        if (self.callbacks.fire_hashchange) |fire_fn| {
            try fire_fn(self.allocator, window_id, .{
                .old_url = old_url,
                .new_url = new_url,
            });
        }
    }

    /// Fire a beforeunload event on the Window object
    ///
    /// HTML Standard §7.2.7.7:
    /// "The beforeunload event is fired when the window, the document and its
    /// resources are about to be unloaded."
    ///
    /// Returns: true if the event was canceled (show prompt), false otherwise
    pub fn fireBeforeUnload(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
    ) !bool {
        if (self.callbacks.fire_beforeunload) |fire_fn| {
            return try fire_fn(self.allocator, window_id, .{});
        }
        return false; // Default: allow unload
    }

    /// Fire a pagehide event on the Window object
    ///
    /// HTML Standard §7.2.7.6:
    /// "The pagehide event is fired when traversing to a document from another,
    /// when the previous document is about to be hidden."
    pub fn firePageHide(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
        persisted: bool,
    ) !void {
        if (self.callbacks.fire_page_transition) |fire_fn| {
            try fire_fn(self.allocator, window_id, .{
                .event_type = "pagehide",
                .persisted = persisted,
            });
        }
    }

    /// Fire a pageshow event on the Window object
    ///
    /// HTML Standard §7.2.7.6:
    /// "The pageshow event is fired when traversing to a document,
    /// when the document is shown."
    pub fn firePageShow(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
        persisted: bool,
    ) !void {
        if (self.callbacks.fire_page_transition) |fire_fn| {
            try fire_fn(self.allocator, window_id, .{
                .event_type = "pageshow",
                .persisted = persisted,
            });
        }
    }

    /// Fire an unload event on the Window object
    ///
    /// HTML Standard §8.1.5.6:
    /// "The unload event is fired when the document or a child resource is being unloaded."
    pub fn fireUnload(
        self: *const NavigationEventDispatcher,
        window_id: WindowId,
    ) !void {
        if (self.callbacks.fire_unload) |fire_fn| {
            try fire_fn(self.allocator, window_id, .{});
        }
    }
};

// ============================================================================
// Convenience functions using global dispatcher
// ============================================================================

/// Fire hashchange event using global dispatcher
pub fn fireHashChangeEvent(
    old_url: []const u8,
    new_url: []const u8,
    window_id: WindowId,
) !void {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        try dispatcher.fireHashChange(window_id, old_url, new_url);
    }
}

/// Fire popstate event using global dispatcher
pub fn firePopStateEvent(
    state: ?SerializedState,
    window_id: WindowId,
) !void {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        try dispatcher.firePopState(window_id, state, false);
    }
}

/// Fire beforeunload event using global dispatcher
pub fn fireBeforeUnloadEvent(window_id: WindowId) !bool {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        return dispatcher.fireBeforeUnload(window_id);
    }
    return false;
}

/// Fire pagehide event using global dispatcher
pub fn firePageHideEvent(persisted: bool, window_id: WindowId) !void {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        try dispatcher.firePageHide(window_id, persisted);
    }
}

/// Fire pageshow event using global dispatcher
pub fn firePageShowEvent(persisted: bool, window_id: WindowId) !void {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        try dispatcher.firePageShow(window_id, persisted);
    }
}

/// Fire unload event using global dispatcher
pub fn fireUnloadEvent(window_id: WindowId) !void {
    if (NavigationEventDispatcher.getGlobal()) |dispatcher| {
        try dispatcher.fireUnload(window_id);
    }
}

// ============================================================================
// Tests
// ============================================================================

test "NavigationEventDispatcher - init" {
    const allocator = std.testing.allocator;
    const dispatcher = NavigationEventDispatcher.init(allocator, .{});
    _ = dispatcher;
}

test "NavigationEventDispatcher - fire without callbacks is noop" {
    const allocator = std.testing.allocator;
    const dispatcher = NavigationEventDispatcher.init(allocator, .{});

    // Dummy window ID
    var window: u64 = 123;
    const window_id: WindowId = @ptrCast(&window);

    // These should not error even without callbacks
    try dispatcher.fireHashChange(window_id, "old", "new");
    try dispatcher.firePopState(window_id, null, false);
    const canceled = try dispatcher.fireBeforeUnload(window_id);
    try std.testing.expect(!canceled);
    try dispatcher.firePageHide(window_id, false);
    try dispatcher.firePageShow(window_id, true);
    try dispatcher.fireUnload(window_id);
}

test "PopStateEventData - constants" {
    try std.testing.expectEqualStrings("popstate", PopStateEventData.event_type);
    try std.testing.expect(PopStateEventData.bubbles);
    try std.testing.expect(!PopStateEventData.cancelable);
}

test "HashChangeEventData - constants" {
    try std.testing.expectEqualStrings("hashchange", HashChangeEventData.event_type);
    try std.testing.expect(HashChangeEventData.bubbles);
    try std.testing.expect(!HashChangeEventData.cancelable);
}

test "BeforeUnloadEventData - constants" {
    try std.testing.expectEqualStrings("beforeunload", BeforeUnloadEventData.event_type);
    try std.testing.expect(BeforeUnloadEventData.bubbles);
    try std.testing.expect(BeforeUnloadEventData.cancelable);
}
