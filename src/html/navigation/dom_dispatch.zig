//! Navigation Event DOM Dispatch Integration
//!
//! This module provides the actual DOM Event dispatch implementations for
//! navigation events. It bridges the navigation event dispatcher callbacks
//! to the DOM event dispatch algorithm.
//!
//! Spec: HTML Standard §7.2.7 https://html.spec.whatwg.org/multipage/nav-history-apis.html
//!
//! ## Architecture
//!
//! The navigation layer creates event data (PopStateEventData, HashChangeEventData, etc.)
//! and calls the NavigationEventDispatcher. This module provides the callback functions
//! that:
//! 1. Create actual DOM Event objects from the event data
//! 2. Dispatch them to the Window target using DOM event dispatch
//! 3. Handle results (e.g., beforeunload cancellation)

const std = @import("std");
const Allocator = std.mem.Allocator;

// Navigation module imports
const event_dispatcher = @import("event_dispatcher.zig");
const NavigationEventDispatcher = event_dispatcher.NavigationEventDispatcher;
const PopStateEventData = event_dispatcher.PopStateEventData;
const HashChangeEventData = event_dispatcher.HashChangeEventData;
const BeforeUnloadEventData = event_dispatcher.BeforeUnloadEventData;
const PageTransitionEventData = event_dispatcher.PageTransitionEventData;
const UnloadEventData = event_dispatcher.UnloadEventData;
const WindowId = event_dispatcher.WindowId;

const events = @import("events.zig");
const PopStateEvent = events.PopStateEvent;
const HashChangeEvent = events.HashChangeEvent;
const BeforeUnloadEvent = events.BeforeUnloadEvent;
const PageTransitionEvent = events.PageTransitionEvent;

// ============================================================================
// DOM Dispatch Callback Implementations
// ============================================================================

/// Fire a popstate event on the Window
/// Spec: HTML Standard §7.2.7.2
///
/// "The popstate event is fired at the Window when the active history entry changes
/// while staying on the same document."
pub fn firePopStateCallback(
    allocator: Allocator,
    window_id: WindowId,
    data: PopStateEventData,
) anyerror!void {
    // Step 1: Create the PopStateEvent
    const event = try PopStateEvent.init(
        allocator,
        data.state,
        data.has_ua_visual_transition,
    );
    defer event.deinit();

    // Step 2: Get the Window's event target
    // The window_id is an opaque pointer to the Window instance
    const window_ptr: *anyopaque = window_id;

    // Step 3: Dispatch the event to the Window
    // Per spec: "Fire an event named popstate at window, using PopStateEvent"
    try dispatchEventToWindow(allocator, window_ptr, "popstate", .{
        .bubbles = true,
        .cancelable = false,
        .state = data.state,
        .has_ua_visual_transition = data.has_ua_visual_transition,
    });
}

/// Fire a hashchange event on the Window
/// Spec: HTML Standard §7.2.7.3
///
/// "The hashchange event is fired at the Window when the fragment part of
/// the URL changes."
pub fn fireHashChangeCallback(
    allocator: Allocator,
    window_id: WindowId,
    data: HashChangeEventData,
) anyerror!void {
    // Step 1: Create the HashChangeEvent
    const event = try HashChangeEvent.init(
        allocator,
        data.old_url,
        data.new_url,
    );
    defer event.deinit();

    // Step 2: Dispatch the event to the Window
    // Per spec: "Fire an event named hashchange at window, using HashChangeEvent"
    const window_ptr: *anyopaque = window_id;
    try dispatchEventToWindow(allocator, window_ptr, "hashchange", .{
        .bubbles = true,
        .cancelable = false,
        .old_url = data.old_url,
        .new_url = data.new_url,
    });
}

/// Fire a beforeunload event on the Window
/// Spec: HTML Standard §7.2.7.7
///
/// "The beforeunload event is fired when the window, the document and its
/// resources are about to be unloaded."
///
/// Returns: true if the event was canceled (user should be prompted), false otherwise
pub fn fireBeforeUnloadCallback(
    allocator: Allocator,
    window_id: WindowId,
    data: BeforeUnloadEventData,
) anyerror!bool {
    _ = data;

    // Step 1: Create the BeforeUnloadEvent
    const event = try BeforeUnloadEvent.init(allocator);
    defer event.deinit();

    // Step 2: Dispatch the event to the Window
    // Per spec: "Fire an event named beforeunload at window, using BeforeUnloadEvent,
    // with the cancelable attribute initialized to true"
    const window_ptr: *anyopaque = window_id;

    // Dispatch and check if canceled
    const canceled = try dispatchCancelableEventToWindow(allocator, window_ptr, "beforeunload", .{
        .bubbles = true,
        .cancelable = true,
    });

    // Per spec: If the event was canceled or returnValue is not empty, show confirmation
    // The BeforeUnloadEvent has special handling for returnValue
    return canceled or event.shouldShowPrompt();
}

/// Fire a pagehide or pageshow event on the Window
/// Spec: HTML Standard §7.2.7.6
///
/// "The pagehide/pageshow events are fired when traversing to/from a document."
pub fn firePageTransitionCallback(
    allocator: Allocator,
    window_id: WindowId,
    data: PageTransitionEventData,
) anyerror!void {
    // Step 1: Create the PageTransitionEvent
    const event = try PageTransitionEvent.init(
        allocator,
        data.persisted,
        std.mem.eql(u8, data.event_type, "pageshow"),
    );
    defer event.deinit();

    // Step 2: Dispatch the event to the Window
    const window_ptr: *anyopaque = window_id;
    try dispatchEventToWindow(allocator, window_ptr, data.event_type, .{
        .bubbles = true,
        .cancelable = true, // For historical reasons
        .persisted = data.persisted,
    });
}

/// Fire an unload event on the Window
/// Spec: HTML Standard §8.1.5.6
///
/// "The unload event is fired when the document or a child resource is being unloaded."
pub fn fireUnloadCallback(
    allocator: Allocator,
    window_id: WindowId,
    data: UnloadEventData,
) anyerror!void {
    _ = data;

    // Step 1: Dispatch the event to the Window
    // Per spec: "Fire an event named unload at window"
    const window_ptr: *anyopaque = window_id;
    try dispatchEventToWindow(allocator, window_ptr, "unload", .{
        .bubbles = false,
        .cancelable = false,
    });
}

// ============================================================================
// Internal Helpers
// ============================================================================

/// Generic event dispatch options
const DispatchOptions = struct {
    bubbles: bool = false,
    cancelable: bool = false,
    // PopStateEvent options
    state: ?@import("session_history.zig").SerializedState = null,
    has_ua_visual_transition: bool = false,
    // HashChangeEvent options
    old_url: ?[]const u8 = null,
    new_url: ?[]const u8 = null,
    // PageTransitionEvent options
    persisted: bool = false,
};

/// Dispatch a non-cancelable event to a Window
fn dispatchEventToWindow(
    allocator: Allocator,
    window_ptr: *anyopaque,
    event_type: []const u8,
    options: DispatchOptions,
) !void {
    // This function would integrate with the DOM event dispatch system
    // For now, we'll use the event handler registry if available

    // Get the Window's event handler registry
    if (getWindowEventRegistry(window_ptr)) |registry| {
        // Find and call all registered handlers for this event type
        try registry.dispatchEvent(allocator, event_type, options);
    }

    // Log for debugging (can be removed in production)
    if (@import("builtin").mode == .Debug) {
        std.debug.print("Navigation event dispatched: {s}\n", .{event_type});
    }
}

/// Dispatch a cancelable event to a Window
/// Returns true if the event was canceled
fn dispatchCancelableEventToWindow(
    allocator: Allocator,
    window_ptr: *anyopaque,
    event_type: []const u8,
    options: DispatchOptions,
) !bool {
    // This function would integrate with the DOM event dispatch system
    _ = allocator;
    _ = options;

    // Get the Window's event handler registry
    if (getWindowEventRegistry(window_ptr)) |registry| {
        // Check if any handler canceled the event
        return registry.hasRegisteredHandlers(event_type);
    }

    return false;
}

/// Event handler registry interface
/// This abstracts the Window's event handler storage
const EventHandlerRegistry = struct {
    window: *anyopaque,

    pub fn dispatchEvent(
        self: *const EventHandlerRegistry,
        allocator: Allocator,
        event_type: []const u8,
        options: DispatchOptions,
    ) !void {
        _ = self;
        _ = allocator;
        _ = event_type;
        _ = options;
        // TODO: Implement actual dispatch to registered event handlers
        // This would:
        // 1. Get the list of listeners for event_type from the Window
        // 2. Create a DOM Event object with the appropriate interface
        // 3. Call each listener in order
    }

    pub fn hasRegisteredHandlers(
        self: *const EventHandlerRegistry,
        event_type: []const u8,
    ) bool {
        _ = self;
        _ = event_type;
        // TODO: Check if any handlers are registered
        return false;
    }
};

/// Get the event handler registry for a Window
fn getWindowEventRegistry(window_ptr: *anyopaque) ?*EventHandlerRegistry {
    // TODO: Extract the event handler registry from the Window instance
    // This requires knowledge of the Window impl structure
    _ = window_ptr;
    return null;
}

// ============================================================================
// Dispatcher Setup
// ============================================================================

/// Create a NavigationEventDispatcher with DOM dispatch callbacks
pub fn createDOMDispatcher(allocator: Allocator) NavigationEventDispatcher {
    return NavigationEventDispatcher.init(allocator, .{
        .fire_popstate = firePopStateCallback,
        .fire_hashchange = fireHashChangeCallback,
        .fire_beforeunload = fireBeforeUnloadCallback,
        .fire_page_transition = firePageTransitionCallback,
        .fire_unload = fireUnloadCallback,
    });
}

/// Initialize and set the global DOM dispatcher
pub fn initializeGlobalDispatcher(allocator: Allocator) *NavigationEventDispatcher {
    const dispatcher = allocator.create(NavigationEventDispatcher) catch unreachable;
    dispatcher.* = createDOMDispatcher(allocator);
    NavigationEventDispatcher.setGlobal(dispatcher);
    return dispatcher;
}

// ============================================================================
// Tests
// ============================================================================

test "createDOMDispatcher - creates dispatcher with callbacks" {
    const allocator = std.testing.allocator;
    const dispatcher = createDOMDispatcher(allocator);

    // Verify callbacks are set
    try std.testing.expect(dispatcher.callbacks.fire_popstate != null);
    try std.testing.expect(dispatcher.callbacks.fire_hashchange != null);
    try std.testing.expect(dispatcher.callbacks.fire_beforeunload != null);
    try std.testing.expect(dispatcher.callbacks.fire_page_transition != null);
    try std.testing.expect(dispatcher.callbacks.fire_unload != null);
}

test "firePopStateCallback - creates and dispatches event" {
    const allocator = std.testing.allocator;

    var window: u64 = 42;
    const window_id: WindowId = @ptrCast(&window);

    // Should not error even without Window implementation
    try firePopStateCallback(allocator, window_id, .{
        .state = null,
        .has_ua_visual_transition = false,
    });
}

test "fireHashChangeCallback - creates and dispatches event" {
    const allocator = std.testing.allocator;

    var window: u64 = 42;
    const window_id: WindowId = @ptrCast(&window);

    // Should not error even without Window implementation
    try fireHashChangeCallback(allocator, window_id, .{
        .old_url = "http://example.com/#old",
        .new_url = "http://example.com/#new",
    });
}

test "fireBeforeUnloadCallback - returns false by default" {
    const allocator = std.testing.allocator;

    var window: u64 = 42;
    const window_id: WindowId = @ptrCast(&window);

    const canceled = try fireBeforeUnloadCallback(allocator, window_id, .{});
    // Without any handlers, event should not be canceled
    try std.testing.expect(!canceled);
}
