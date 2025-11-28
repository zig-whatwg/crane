//! Implementation for DOMStringList interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/common-dom-interfaces.html#domstringlist
//! HTML Standard
//!
//! DOMStringList is a simple list of DOMString values. It provides methods
//! to access strings by index and to check for the presence of a string.
//!
//! This interface is used by various Web APIs (e.g., location.ancestorOrigins,
//! DataTransfer.types, etc.) to expose read-only lists of strings.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const infra = @import("infra");
const DOMStringList = interfaces.DOMStringList;

pub const State = DOMStringList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for DOMStringList implementation
/// Stores the list of strings
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// The list of strings
    /// Each string is owned by this list
    strings: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .strings = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *InternalState) void {
        // Free all owned strings
        for (self.strings.items) |str| {
            self.allocator.free(str);
        }
        self.strings.deinit();
    }
};

/// Get the internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Initialize instance (creates the instance)
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

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    runtime.Instance.deinit(instance);
}

/// Create an empty DOMStringList
pub fn createEmpty(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    return try init(allocator, State, &interfaces.DOMStringList.vtable, ctx);
}

/// Create a DOMStringList from a slice of strings
/// The strings are copied, so the caller retains ownership of the input slice
pub fn createFromSlice(allocator: std.mem.Allocator, ctx: runtime.Context, strings: []const []const u8) !*runtime.Instance {
    const instance = try init(allocator, State, &interfaces.DOMStringList.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Copy all strings into the list
    for (strings) |str| {
        const owned = try allocator.dupe(u8, str);
        errdefer allocator.free(owned);
        try internal.strings.append(owned);
    }

    return instance;
}

// =============================================================================
// Getters
// =============================================================================

/// HTML §2.6.3 - DOMStringList.length
/// Returns the number of strings in the list.
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return @intCast(internal.strings.items.len);
}

// =============================================================================
// Operations
// =============================================================================

/// HTML §2.6.3 - DOMStringList.item(index)
/// Returns the string at the given index, or null if index is out of range.
///
/// This method is also the getter for indexed properties, allowing
/// list[index] access in JavaScript.
pub fn call_item(instance: *runtime.Instance, index: u32) ImplError!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Check bounds
    if (index >= internal.strings.items.len) {
        // Return null (empty string represents null for this case)
        // Per spec, item() returns null for out-of-bounds access
        return runtime.DOMString.initEmpty();
    }

    // Return the string at the index
    return runtime.DOMString.initInterned(internal.strings.items[index]);
}

/// HTML §2.6.3 - DOMStringList.contains(string)
/// Returns true if the list contains the given string.
pub fn call_contains(instance: *runtime.Instance, string: runtime.DOMString) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const search = string.asSlice();

    // Linear search through the list
    for (internal.strings.items) |str| {
        if (std.mem.eql(u8, str, search)) {
            return true;
        }
    }

    return false;
}

// =============================================================================
// Helper functions for building DOMStringList instances
// =============================================================================

/// Add a string to the list (used internally by APIs that build DOMStringLists)
pub fn appendString(instance: *runtime.Instance, str: []const u8) !void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Copy the string
    const owned = try internal.allocator.dupe(u8, str);
    errdefer internal.allocator.free(owned);

    try internal.strings.append(owned);
}

/// Get the string at an index (non-throwing helper)
pub fn getString(instance: *runtime.Instance, index: usize) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    if (index >= internal.strings.items.len) return null;
    return internal.strings.items[index];
}

/// Get all strings as a slice (for iteration)
pub fn getStrings(instance: *runtime.Instance) ?[]const []const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.strings.items;
}
