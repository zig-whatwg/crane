//! Implementation for NavigationHistoryEntry interface
//!
//! HTML Standard §7.2.6.1 - The NavigationHistoryEntry interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationhistoryentry
//!
//! NavigationHistoryEntry represents a single entry in the navigation history.
//! Each entry has a unique key (for traverseTo), an id, and associated state.
//!
//! ## Key Concepts
//!
//! - **key**: Stable identifier for traverseTo() - survives page reloads
//! - **id**: Unique identifier for this specific entry
//! - **index**: Position in entries() array (-1 if disposed)
//! - **state**: User-defined state object (via updateCurrentEntry)

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigationHistoryEntry = interfaces.NavigationHistoryEntry;

// HTML navigation infrastructure
const html_core = @import("html_core");
const SessionHistoryEntry = html_core.navigation.SessionHistoryEntry;

pub const State = NavigationHistoryEntry.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Static sentinel for representing "undefined" return values.
/// Used instead of null to provide a valid pointer that represents
/// undefined/empty results from operations that return *const anyopaque.
var undefined_sentinel: u8 = 0;

/// Internal state for NavigationHistoryEntry implementation
pub const InternalState = struct {
    /// Allocator for this entry's resources
    allocator: Allocator,

    /// The underlying session history entry
    /// This is the source of truth for URL, key, id, and state
    session_entry: ?*SessionHistoryEntry = null,

    /// The index of this entry in the entries() array
    /// -1 indicates the entry has been disposed
    index: i64 = -1,

    /// Whether this entry represents a same-document navigation
    same_document: bool = false,

    /// Event handler for dispose event (EventHandler is already optional)
    ondispose: typedefs.EventHandler = null,

    /// Whether this entry has been disposed
    disposed: bool = false,

    pub fn init(allocator: Allocator) InternalState {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        // We don't own the session entry - it's owned by the session history
        _ = self;
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize NavigationHistoryEntry instance
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

/// Deinitialize NavigationHistoryEntry instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

// ============================================================================
// Factory Function
// ============================================================================

/// Create a NavigationHistoryEntry wrapper for a session history entry
pub fn createForSessionEntry(
    allocator: Allocator,
    ctx: runtime.Context,
    session_entry: *SessionHistoryEntry,
    index: i64,
    same_document: bool,
) !*runtime.Instance {
    const instance = try init(allocator, State, &NavigationHistoryEntry.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.session_entry = session_entry;
    internal.index = index;
    internal.same_document = same_document;

    return instance;
}

// ============================================================================
// Property Getters
// ============================================================================

/// Getter for url
/// HTML Standard §7.2.6.1: Returns the URL of this entry, or null if disposed
pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
    const internal = getInternal(instance) orelse return null;

    // Return null if disposed
    if (internal.disposed) return null;

    const entry = internal.session_entry orelse return null;
    // USVString is just []const u8
    return entry.url;
}

/// Getter for key
/// HTML Standard §7.2.6.1: Returns the unique key for traverseTo()
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.session_entry orelse return error.InvalidStateError;

    // Return the navigation API key (UUID)
    return runtime.DOMString.initInterned(&entry.navigation_api_key);
}

/// Getter for id
/// HTML Standard §7.2.6.1: Returns the unique ID for this entry
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.session_entry orelse return error.InvalidStateError;

    // Return the navigation API ID (UUID)
    return runtime.DOMString.initInterned(&entry.navigation_api_id);
}

/// Getter for index
/// HTML Standard §7.2.6.1: Returns the index in entries(), or -1 if disposed
pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Return -1 if disposed
    if (internal.disposed) return -1;

    return internal.index;
}

/// Getter for sameDocument
/// HTML Standard §7.2.6.1: Returns true if this was a same-document navigation
pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.same_document;
}

/// Getter for ondispose
pub fn get_ondispose(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.ondispose;
}

/// Setter for ondispose
pub fn set_ondispose(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.ondispose = value;
}

// ============================================================================
// Operations
// ============================================================================

/// Operation: getState()
/// HTML Standard §7.2.6.1: Returns a clone of the navigation API state
pub fn call_getState(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.session_entry orelse return error.InvalidStateError;

    // Return the serialized state
    // In full implementation, this would deserialize and return a clone
    const state = &entry.navigation_api_state;

    // Check for undefined (initial state) - return sentinel
    if (state.isUndefined()) {
        return &undefined_sentinel;
    }

    // Return the state data pointer
    return @ptrCast(state.data.ptr);
}

// ============================================================================
// Internal Helper Functions
// ============================================================================

/// Mark this entry as disposed
/// Called when the entry is removed from the session history
pub fn markDisposed(instance: *runtime.Instance) void {
    const internal = getInternal(instance) orelse return;

    if (internal.disposed) return;

    internal.disposed = true;
    internal.index = -1;

    // Fire dispose event
    // In full implementation, this would dispatch the event
}

/// Update the index of this entry
/// Called when entries are added/removed from the session history
pub fn updateIndex(instance: *runtime.Instance, new_index: i64) void {
    const internal = getInternal(instance) orelse return;
    internal.index = new_index;
}

/// Check if this entry is disposed
pub fn isDisposed(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return true;
    return internal.disposed;
}
