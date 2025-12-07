//! Implementation for History interface
//!
//! Implements the History interface per HTML Standard §7.2.2.
//! Spec: https://html.spec.whatwg.org/multipage/history.html#the-history-interface
//!
//! ## Overview
//!
//! The History interface provides access to the browsing context's session history.
//! It allows navigation through history entries and manipulation via pushState/replaceState.
//!
//! ## Session History
//!
//! Each entry in the session history consists of:
//! - A URL
//! - Optional state data (serialized via structured clone)
//! - Optional scroll position
//!
//! ## Security
//!
//! Cross-origin access to history.length is restricted per same-origin policy.
//! pushState/replaceState can only change URL within same origin.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const History = interfaces.History;

pub const State = History.State;

pub const ImplError = error{
    NotImplemented,
    SecurityError,
    InvalidStateError,
    DataCloneError,
    OutOfMemory,
};

/// A single entry in the session history
pub const HistoryEntry = struct {
    /// The URL for this entry
    url: []const u8,

    /// Serialized state data (structured clone)
    state: ?[]const u8 = null,

    /// Scroll position when this entry was created
    scroll_x: i32 = 0,
    scroll_y: i32 = 0,

    pub fn deinit(self: *HistoryEntry, allocator: Allocator) void {
        allocator.free(self.url);
        if (self.state) |state| {
            allocator.free(state);
        }
    }
};

/// Internal state for History implementation
pub const InternalState = struct {
    /// Allocator for history resources
    allocator: Allocator,

    /// Associated document's window
    window: ?*runtime.Instance = null,

    /// Session history entries for this browsing context
    entries: std.ArrayListUnmanaged(HistoryEntry) = .{},

    /// Current index in the entries list
    current_index: usize = 0,

    /// Scroll restoration preference
    scroll_restoration: enums.ScrollRestoration = ._auto_,

    pub fn deinit(self: *InternalState) void {
        for (self.entries.items) |*entry| {
            entry.deinit(self.allocator);
        }
        self.entries.deinit(self.allocator);
    }

    /// Get the current entry (if any)
    pub fn currentEntry(self: *const InternalState) ?*const HistoryEntry {
        if (self.entries.items.len == 0) return null;
        if (self.current_index >= self.entries.items.len) return null;
        return &self.entries.items[self.current_index];
    }
};

/// Helper to get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .allocator = allocator,
    };

    // Store internal state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
}

// =============================================================================
// Property Getters/Setters
// =============================================================================

/// Getter for length
/// Per spec §7.2.2: Returns the number of entries in the joint session history.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return the number of entries
    // Note: For security, cross-origin access may return different values
    return @intCast(internal.entries.items.len);
}

/// Getter for scrollRestoration
/// Per spec §7.2.2: Returns the scroll restoration mode for this entry.
pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!enums.ScrollRestoration {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.scroll_restoration;
}

/// Setter for scrollRestoration
/// Per spec §7.2.2: Sets the scroll restoration mode for the current entry.
pub fn set_scrollRestoration(instance: *runtime.Instance, value: enums.ScrollRestoration) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.scroll_restoration = value;
}

/// Getter for state
/// Per spec §7.2.2: Returns the current state object, or null.
pub fn get_state(instance: *runtime.Instance) anyerror!v8.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get current entry's state
    if (internal.currentEntry()) |entry| {
        if (entry.state) |state| {
            // Return pointer to the state data
            // Note: This should be deserialized via structured clone
            return @ptrCast(state.ptr);
        }
    }

    // Return null if no state
    // Note: We return error here since we can't return a null pointer
    // The interface layer will need to handle this
    return error.NotImplemented;
}

// =============================================================================
// Navigation Methods
// =============================================================================

/// Operation: go
/// Per spec §7.2.2: Navigate to an entry in the session history by delta.
pub fn call_go(instance: *runtime.Instance, delta: webidl.Opt(i32)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Get delta value (default 0)
    const delta_val: i32 = if (delta.wasPassed()) delta.getValue() else 0;

    // If delta is 0, reload
    if (delta_val == 0) {
        // TODO: Trigger reload
        return error.NotImplemented;
    }

    // Calculate target index
    const current = @as(i64, @intCast(internal.current_index));
    const target = current + delta_val;

    // Check bounds
    if (target < 0 or target >= @as(i64, @intCast(internal.entries.items.len))) {
        // Out of bounds - do nothing per spec
        return;
    }

    // Update current index
    internal.current_index = @intCast(target);

    // TODO: Actually navigate and fire popstate event
    // This requires the full navigation implementation from Phase 6
    return error.NotImplemented;
}

/// Operation: back
/// Per spec §7.2.2: Navigate back one entry (equivalent to go(-1)).
pub fn call_back(instance: *runtime.Instance) anyerror!void {
    const delta = webidl.Opt(i32).passed(-1);
    return call_go(instance, delta);
}

/// Operation: forward
/// Per spec §7.2.2: Navigate forward one entry (equivalent to go(1)).
pub fn call_forward(instance: *runtime.Instance) anyerror!void {
    const delta = webidl.Opt(i32).passed(1);
    return call_go(instance, delta);
}

/// Operation: pushState
/// Per spec §7.2.2: Push a new entry onto the session history.
pub fn call_pushState(instance: *runtime.Instance, data: v8.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = unused; // The second parameter is unused per spec (legacy)

    // TODO: Serialize state data via structured clone
    // For now, we just note that state was provided
    _ = data; // Would need structured clone serialization here

    // Get the URL to use
    var new_url: []const u8 = "";
    if (url.wasPassed()) {
        if (url.getValue()) |u| {
            new_url = u;
        }
    }

    // If no URL provided, use current document's URL
    if (new_url.len == 0) {
        // TODO: Get current document URL
        return error.NotImplemented;
    }

    // TODO: Validate URL is same-origin
    // TODO: Parse URL relative to current document

    // Create new entry
    const entry = HistoryEntry{
        .url = try internal.allocator.dupe(u8, new_url),
        .state = null, // TODO: serialized_state
    };

    // Remove any forward entries (everything after current_index)
    while (internal.entries.items.len > internal.current_index + 1) {
        const last_idx = internal.entries.items.len - 1;
        var removed = internal.entries.items[last_idx];
        removed.deinit(internal.allocator);
        internal.entries.items.len -= 1;
    }

    // Add new entry
    try internal.entries.append(internal.allocator, entry);
    internal.current_index = internal.entries.items.len - 1;

    // Note: pushState does NOT fire popstate event per spec
}

/// Operation: replaceState
/// Per spec §7.2.2: Replace the current entry in session history.
pub fn call_replaceState(instance: *runtime.Instance, data: v8.JSValue, unused: runtime.DOMString, url: webidl.Opt(?runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = unused; // The second parameter is unused per spec (legacy)
    _ = data; // TODO: Serialize via structured clone

    // Get the URL to use
    var new_url: []const u8 = "";
    if (url.wasPassed()) {
        if (url.getValue()) |u| {
            new_url = u;
        }
    }

    // If no URL provided, keep current URL
    if (new_url.len == 0) {
        if (internal.currentEntry()) |current| {
            new_url = current.url;
        } else {
            return error.InvalidStateError;
        }
    }

    // TODO: Validate URL is same-origin
    // TODO: Parse URL relative to current document

    // Replace current entry
    if (internal.entries.items.len == 0) {
        // No entries yet, add one
        const entry = HistoryEntry{
            .url = try internal.allocator.dupe(u8, new_url),
            .state = null, // TODO: serialized_state
        };
        try internal.entries.append(internal.allocator, entry);
        internal.current_index = 0;
    } else {
        // Replace existing entry
        var current = &internal.entries.items[internal.current_index];

        // Free old data
        internal.allocator.free(current.url);
        if (current.state) |state| {
            internal.allocator.free(state);
        }

        // Set new data
        current.url = try internal.allocator.dupe(u8, new_url);
        current.state = null; // TODO: serialized_state
    }

    // Note: replaceState does NOT fire popstate event per spec
}
