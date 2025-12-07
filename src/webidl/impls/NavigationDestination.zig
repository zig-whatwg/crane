//! Implementation for NavigationDestination interface
//!
//! HTML Standard §7.2.6.5 - The NavigationDestination interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationdestination
//!
//! NavigationDestination represents the target of a navigation in the
//! NavigateEvent. It provides information about where the navigation
//! is going before it happens.
//!
//! ## Key Differences from NavigationHistoryEntry
//!
//! NavigationDestination is similar to NavigationHistoryEntry but:
//! - Only exists during the navigate event (not persistent)
//! - key/id may be null for new entries (push navigation)
//! - getState() returns the state that WILL be set, not current state

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigationDestination = interfaces.NavigationDestination;

pub const State = NavigationDestination.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Static sentinel for representing "undefined" return values.
/// Used instead of null to provide a valid pointer that represents
/// undefined/empty results from operations that return *const anyopaque.
var undefined_sentinel: u8 = 0;

/// Internal state for NavigationDestination implementation
pub const InternalState = struct {
    /// Allocator for this destination's resources
    allocator: Allocator,

    /// The destination URL
    url: []const u8 = "",

    /// The key of the destination entry (null for new entries)
    key: ?[]const u8 = null,

    /// The id of the destination entry (null for new entries)
    id: ?[]const u8 = null,

    /// The index of the destination entry (-1 for new entries)
    index: i64 = -1,

    /// Whether this is a same-document navigation
    same_document: bool = false,

    /// The state that will be set on the destination entry
    state: ?*const anyopaque = null,

    pub fn init(allocator: Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.url.len > 0) {
            self.allocator.free(self.url);
        }
        if (self.key) |k| {
            self.allocator.free(k);
        }
        if (self.id) |i| {
            self.allocator.free(i);
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize NavigationDestination instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize NavigationDestination instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Factory Functions
// ============================================================================

/// Create a NavigationDestination for a new entry (push navigation)
pub fn createForNewEntry(
    allocator: Allocator,
    ctx: runtime.Context,
    url: []const u8,
    state_ptr: ?*const anyopaque,
) !*runtime.Instance {
    const instance = try init(allocator, State, &NavigationDestination.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.url = try allocator.dupe(u8, url);
    internal.state = state_ptr;
    // key, id, and index are null/-1 for new entries
    internal.index = -1;

    return instance;
}

/// Create a NavigationDestination for an existing entry (traverse navigation)
pub fn createForExistingEntry(
    allocator: Allocator,
    ctx: runtime.Context,
    url: []const u8,
    key: []const u8,
    id: []const u8,
    index: i64,
    same_document: bool,
    state_ptr: ?*const anyopaque,
) !*runtime.Instance {
    const instance = try init(allocator, State, &NavigationDestination.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.url = try allocator.dupe(u8, url);
    internal.key = try allocator.dupe(u8, key);
    internal.id = try allocator.dupe(u8, id);
    internal.index = index;
    internal.same_document = same_document;
    internal.state = state_ptr;

    return instance;
}

// ============================================================================
// Property Getters
// ============================================================================

/// Getter for url
/// HTML Standard §7.2.6.5: Returns the destination URL
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    // USVString is just []const u8
    return internal.url;
}

/// Getter for key
/// HTML Standard §7.2.6.5: Returns the key, or empty string for new entries
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.key) |k| {
        return runtime.DOMString.initInterned(k);
    }
    // Return empty string for new entries
    return runtime.DOMString.initInterned("");
}

/// Getter for id
/// HTML Standard §7.2.6.5: Returns the id, or empty string for new entries
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    if (internal.id) |i| {
        return runtime.DOMString.initInterned(i);
    }
    // Return empty string for new entries
    return runtime.DOMString.initInterned("");
}

/// Getter for index
/// HTML Standard §7.2.6.5: Returns the index, or -1 for new entries
pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.index;
}

/// Getter for sameDocument
/// HTML Standard §7.2.6.5: Returns true if this will be same-document navigation
pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.same_document;
}

// ============================================================================
// Operations
// ============================================================================

/// Operation: getState()
/// HTML Standard §7.2.6.5: Returns the state that will be set on the entry
pub fn call_getState(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return the state pointer, or sentinel for undefined
    return internal.state orelse &undefined_sentinel;
}
