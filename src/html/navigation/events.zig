//! Navigation Events - HTML Standard §7.2.7
//!
//! This module implements the navigation-related events:
//! - popstate: Fired when traversing session history
//! - hashchange: Fired when fragment identifier changes
//! - beforeunload: Fired before unloading document
//! - pagehide: Fired when document is being unloaded
//! - pageshow: Fired when document is shown
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#event-interfaces

const std = @import("std");
const Allocator = std.mem.Allocator;

const session_history = @import("session_history.zig");
const SerializedState = session_history.SerializedState;

// ============================================================================
// PopStateEvent - HTML Standard §7.2.7.2
// ============================================================================

/// The PopStateEvent interface
///
/// HTML Standard §7.2.7.2:
/// "interface PopStateEvent : Event {
///   constructor(DOMString type, optional PopStateEventInit eventInitDict = {});
///   readonly attribute any state;
///   readonly attribute boolean hasUAVisualTransition;
/// };"
pub const PopStateEvent = struct {
    allocator: Allocator,

    /// Base event fields
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    /// The state object provided to pushState() or replaceState()
    state: ?SerializedState,

    /// Whether the UA performed a visual transition before dispatching
    has_ua_visual_transition: bool,

    /// Create a new PopStateEvent
    pub fn init(
        allocator: Allocator,
        state: ?SerializedState,
        has_ua_visual_transition: bool,
    ) !*PopStateEvent {
        const event = try allocator.create(PopStateEvent);
        event.* = .{
            .allocator = allocator,
            .event_type = "popstate",
            .bubbles = true,
            .cancelable = false,
            .state = state,
            .has_ua_visual_transition = has_ua_visual_transition,
        };
        return event;
    }

    /// Free resources
    pub fn deinit(self: *PopStateEvent) void {
        if (self.state) |*s| {
            s.deinit();
        }
        self.allocator.destroy(self);
    }

    /// Get the state
    pub fn getState(self: *const PopStateEvent) ?*const SerializedState {
        if (self.state) |*s| {
            return s;
        }
        return null;
    }
};

/// PopStateEvent initialization dictionary
pub const PopStateEventInit = struct {
    /// State data (will be structured-deserialized)
    state: ?[]const u8 = null,
    /// Whether the UA performed a visual transition
    has_ua_visual_transition: bool = false,
    /// Whether the event bubbles
    bubbles: bool = true,
    /// Whether the event is cancelable
    cancelable: bool = false,
};

// ============================================================================
// HashChangeEvent - HTML Standard §7.2.7.3
// ============================================================================

/// The HashChangeEvent interface
///
/// HTML Standard §7.2.7.3:
/// "interface HashChangeEvent : Event {
///   constructor(DOMString type, optional HashChangeEventInit eventInitDict = {});
///   readonly attribute USVString oldURL;
///   readonly attribute USVString newURL;
/// };"
pub const HashChangeEvent = struct {
    allocator: Allocator,

    /// Base event fields
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    /// The URL of the session history entry that was traversed from
    old_url: []const u8,

    /// The URL of the session history entry that was traversed to
    new_url: []const u8,

    /// Create a new HashChangeEvent
    pub fn init(
        allocator: Allocator,
        old_url: []const u8,
        new_url: []const u8,
    ) !*HashChangeEvent {
        const event = try allocator.create(HashChangeEvent);
        event.* = .{
            .allocator = allocator,
            .event_type = "hashchange",
            .bubbles = true,
            .cancelable = false,
            .old_url = try allocator.dupe(u8, old_url),
            .new_url = try allocator.dupe(u8, new_url),
        };
        return event;
    }

    /// Free resources
    pub fn deinit(self: *HashChangeEvent) void {
        self.allocator.free(self.old_url);
        self.allocator.free(self.new_url);
        self.allocator.destroy(self);
    }
};

/// HashChangeEvent initialization dictionary
pub const HashChangeEventInit = struct {
    /// The previous URL
    old_url: []const u8 = "",
    /// The new URL
    new_url: []const u8 = "",
    /// Whether the event bubbles
    bubbles: bool = true,
    /// Whether the event is cancelable
    cancelable: bool = false,
};

// ============================================================================
// PageTransitionEvent - HTML Standard §7.2.7.6
// ============================================================================

/// The PageTransitionEvent interface
///
/// HTML Standard §7.2.7.6:
/// "interface PageTransitionEvent : Event {
///   constructor(DOMString type, optional PageTransitionEventInit eventInitDict = {});
///   readonly attribute boolean persisted;
/// };"
pub const PageTransitionEvent = struct {
    allocator: Allocator,

    /// Base event fields
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    /// For pageshow: false if newly loading, true if from bfcache
    /// For pagehide: false if going away for the last time, true if might be reused
    persisted: bool,

    /// Create a new PageTransitionEvent
    pub fn init(
        allocator: Allocator,
        event_type: []const u8,
        persisted: bool,
    ) !*PageTransitionEvent {
        const event = try allocator.create(PageTransitionEvent);
        event.* = .{
            .allocator = allocator,
            .event_type = try allocator.dupe(u8, event_type),
            .bubbles = true,
            .cancelable = true, // Historical reasons per spec
            .persisted = persisted,
        };
        return event;
    }

    /// Free resources
    pub fn deinit(self: *PageTransitionEvent) void {
        self.allocator.free(self.event_type);
        self.allocator.destroy(self);
    }
};

/// PageTransitionEvent initialization dictionary
pub const PageTransitionEventInit = struct {
    /// Whether the page is being persisted (bfcache)
    persisted: bool = false,
    /// Whether the event bubbles (always true for historical reasons)
    bubbles: bool = true,
    /// Whether the event is cancelable (always true for historical reasons)
    cancelable: bool = true,
};

// ============================================================================
// BeforeUnloadEvent - HTML Standard §7.2.7.7
// ============================================================================

/// The BeforeUnloadEvent interface
///
/// HTML Standard §7.2.7.7:
/// "interface BeforeUnloadEvent : Event {
///   attribute DOMString returnValue;
/// };"
///
/// Note: There are no BeforeUnloadEvent-specific initialization methods.
/// The BeforeUnloadEvent interface is a legacy interface.
pub const BeforeUnloadEvent = struct {
    allocator: Allocator,

    /// Base event fields
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    /// Legacy attribute for controlling unload prompt
    /// Any value besides the empty string is treated as a request to show prompt
    return_value: []const u8,

    /// Whether the event was canceled (via preventDefault or returnValue)
    was_canceled: bool,

    /// Create a new BeforeUnloadEvent
    pub fn init(allocator: Allocator) !*BeforeUnloadEvent {
        const event = try allocator.create(BeforeUnloadEvent);
        event.* = .{
            .allocator = allocator,
            .event_type = "beforeunload",
            .bubbles = true,
            .cancelable = true,
            .return_value = "",
            .was_canceled = false,
        };
        return event;
    }

    /// Free resources
    pub fn deinit(self: *BeforeUnloadEvent) void {
        if (self.return_value.len > 0) {
            self.allocator.free(self.return_value);
        }
        self.allocator.destroy(self);
    }

    /// Set the return value (any non-empty value requests prompt)
    pub fn setReturnValue(self: *BeforeUnloadEvent, value: []const u8) !void {
        if (self.return_value.len > 0) {
            self.allocator.free(self.return_value);
        }
        self.return_value = try self.allocator.dupe(u8, value);
    }

    /// Check if unload should show a prompt
    pub fn shouldShowPrompt(self: *const BeforeUnloadEvent) bool {
        return self.was_canceled or self.return_value.len > 0;
    }

    /// Cancel the event (equivalent to preventDefault)
    pub fn cancel(self: *BeforeUnloadEvent) void {
        self.was_canceled = true;
    }
};

// ============================================================================
// NavigationCurrentEntryChangeEvent - HTML Standard §7.2.7.1
// ============================================================================

/// Navigation type for NavigationCurrentEntryChangeEvent
pub const NavigationType = enum {
    push,
    replace,
    reload,
    traverse,

    pub fn toString(self: NavigationType) []const u8 {
        return switch (self) {
            .push => "push",
            .replace => "replace",
            .reload => "reload",
            .traverse => "traverse",
        };
    }

    pub fn fromString(str: []const u8) ?NavigationType {
        if (std.mem.eql(u8, str, "push")) return .push;
        if (std.mem.eql(u8, str, "replace")) return .replace;
        if (std.mem.eql(u8, str, "reload")) return .reload;
        if (std.mem.eql(u8, str, "traverse")) return .traverse;
        return null;
    }
};

/// The NavigationCurrentEntryChangeEvent interface
///
/// HTML Standard §7.2.7.1:
/// "interface NavigationCurrentEntryChangeEvent : Event {
///   constructor(DOMString type, NavigationCurrentEntryChangeEventInit eventInitDict);
///   readonly attribute NavigationType? navigationType;
///   readonly attribute NavigationHistoryEntry from;
/// };"
pub const NavigationCurrentEntryChangeEvent = struct {
    allocator: Allocator,

    /// Base event fields
    event_type: []const u8,
    bubbles: bool,
    cancelable: bool,

    /// The type of navigation, or null if due to updateCurrentEntry()
    navigation_type: ?NavigationType,

    /// The previous value of navigation.currentEntry
    /// Represented as the entry's key for simplicity
    from_entry_key: [36]u8,

    /// Create a new NavigationCurrentEntryChangeEvent
    pub fn init(
        allocator: Allocator,
        navigation_type: ?NavigationType,
        from_entry_key: [36]u8,
    ) !*NavigationCurrentEntryChangeEvent {
        const event = try allocator.create(NavigationCurrentEntryChangeEvent);
        event.* = .{
            .allocator = allocator,
            .event_type = "currententrychange",
            .bubbles = false,
            .cancelable = false,
            .navigation_type = navigation_type,
            .from_entry_key = from_entry_key,
        };
        return event;
    }

    /// Free resources
    pub fn deinit(self: *NavigationCurrentEntryChangeEvent) void {
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Event Firing Utilities
// ============================================================================

/// Callback type for event handlers
pub const EventHandler = *const fn (event: *anyopaque, context: ?*anyopaque) void;

/// Event dispatcher for navigation events
pub const NavigationEventDispatcher = struct {
    allocator: Allocator,

    /// Registered handlers
    handlers: struct {
        popstate: std.ArrayList(HandlerEntry),
        hashchange: std.ArrayList(HandlerEntry),
        beforeunload: std.ArrayList(HandlerEntry),
        pagehide: std.ArrayList(HandlerEntry),
        pageshow: std.ArrayList(HandlerEntry),
        currententrychange: std.ArrayList(HandlerEntry),
    },

    const HandlerEntry = struct {
        handler: EventHandler,
        context: ?*anyopaque,
    };

    /// Create a new dispatcher
    pub fn init(allocator: Allocator) NavigationEventDispatcher {
        return .{
            .allocator = allocator,
            .handlers = .{
                .popstate = std.ArrayList(HandlerEntry).init(allocator),
                .hashchange = std.ArrayList(HandlerEntry).init(allocator),
                .beforeunload = std.ArrayList(HandlerEntry).init(allocator),
                .pagehide = std.ArrayList(HandlerEntry).init(allocator),
                .pageshow = std.ArrayList(HandlerEntry).init(allocator),
                .currententrychange = std.ArrayList(HandlerEntry).init(allocator),
            },
        };
    }

    /// Free resources
    pub fn deinit(self: *NavigationEventDispatcher) void {
        self.handlers.popstate.deinit();
        self.handlers.hashchange.deinit();
        self.handlers.beforeunload.deinit();
        self.handlers.pagehide.deinit();
        self.handlers.pageshow.deinit();
        self.handlers.currententrychange.deinit();
    }

    /// Add a popstate handler
    pub fn addPopStateHandler(self: *NavigationEventDispatcher, handler: EventHandler, context: ?*anyopaque) !void {
        try self.handlers.popstate.append(.{ .handler = handler, .context = context });
    }

    /// Add a hashchange handler
    pub fn addHashChangeHandler(self: *NavigationEventDispatcher, handler: EventHandler, context: ?*anyopaque) !void {
        try self.handlers.hashchange.append(.{ .handler = handler, .context = context });
    }

    /// Add a beforeunload handler
    pub fn addBeforeUnloadHandler(self: *NavigationEventDispatcher, handler: EventHandler, context: ?*anyopaque) !void {
        try self.handlers.beforeunload.append(.{ .handler = handler, .context = context });
    }

    /// Add a pagehide handler
    pub fn addPageHideHandler(self: *NavigationEventDispatcher, handler: EventHandler, context: ?*anyopaque) !void {
        try self.handlers.pagehide.append(.{ .handler = handler, .context = context });
    }

    /// Add a pageshow handler
    pub fn addPageShowHandler(self: *NavigationEventDispatcher, handler: EventHandler, context: ?*anyopaque) !void {
        try self.handlers.pageshow.append(.{ .handler = handler, .context = context });
    }

    /// Fire a popstate event
    pub fn firePopState(self: *NavigationEventDispatcher, event: *PopStateEvent) void {
        for (self.handlers.popstate.items) |entry| {
            entry.handler(event, entry.context);
        }
    }

    /// Fire a hashchange event
    pub fn fireHashChange(self: *NavigationEventDispatcher, event: *HashChangeEvent) void {
        for (self.handlers.hashchange.items) |entry| {
            entry.handler(event, entry.context);
        }
    }

    /// Fire a beforeunload event and return whether it was canceled
    pub fn fireBeforeUnload(self: *NavigationEventDispatcher, event: *BeforeUnloadEvent) bool {
        for (self.handlers.beforeunload.items) |entry| {
            entry.handler(event, entry.context);
        }
        return event.shouldShowPrompt();
    }

    /// Fire a pagehide event
    pub fn firePageHide(self: *NavigationEventDispatcher, event: *PageTransitionEvent) void {
        for (self.handlers.pagehide.items) |entry| {
            entry.handler(event, entry.context);
        }
    }

    /// Fire a pageshow event
    pub fn firePageShow(self: *NavigationEventDispatcher, event: *PageTransitionEvent) void {
        for (self.handlers.pageshow.items) |entry| {
            entry.handler(event, entry.context);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PopStateEvent - init and deinit" {
    const allocator = std.testing.allocator;

    var state = try SerializedState.nullState(allocator);
    defer state.deinit();

    const event = try PopStateEvent.init(allocator, null, false);
    defer event.deinit();

    try std.testing.expectEqualStrings("popstate", event.event_type);
    try std.testing.expect(event.bubbles);
    try std.testing.expect(!event.cancelable);
}

test "HashChangeEvent - init and deinit" {
    const allocator = std.testing.allocator;

    const event = try HashChangeEvent.init(
        allocator,
        "https://example.com/page#old",
        "https://example.com/page#new",
    );
    defer event.deinit();

    try std.testing.expectEqualStrings("https://example.com/page#old", event.old_url);
    try std.testing.expectEqualStrings("https://example.com/page#new", event.new_url);
}

test "PageTransitionEvent - pageshow" {
    const allocator = std.testing.allocator;

    const event = try PageTransitionEvent.init(allocator, "pageshow", false);
    defer event.deinit();

    try std.testing.expectEqualStrings("pageshow", event.event_type);
    try std.testing.expect(!event.persisted);
}

test "BeforeUnloadEvent - prompt behavior" {
    const allocator = std.testing.allocator;

    const event = try BeforeUnloadEvent.init(allocator);
    defer event.deinit();

    try std.testing.expect(!event.shouldShowPrompt());

    try event.setReturnValue("Are you sure?");
    try std.testing.expect(event.shouldShowPrompt());
}

test "NavigationType - conversion" {
    try std.testing.expectEqualStrings("push", NavigationType.push.toString());
    try std.testing.expectEqual(NavigationType.traverse, NavigationType.fromString("traverse").?);
    try std.testing.expect(NavigationType.fromString("invalid") == null);
}

test "NavigationEventDispatcher - basic" {
    const allocator = std.testing.allocator;

    var dispatcher = NavigationEventDispatcher.init(allocator);
    defer dispatcher.deinit();

    const event = try HashChangeEvent.init(allocator, "old", "new");
    defer event.deinit();

    // No handlers, should not crash
    dispatcher.fireHashChange(event);
}
