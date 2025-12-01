//! Implementation for IDBOpenDBRequest interface
//!
//! Extends IDBRequest with events for database open/upgrade operations.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const IDBOpenDBRequestInterface = interfaces.IDBOpenDBRequest;

// Backend types
const BackendOpenDBRequest = storage.indexeddb.IDBOpenDBRequest;

pub const State = IDBOpenDBRequestInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBOpenDBRequest
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    open_request: ?*BackendOpenDBRequest,

    // Event handlers specific to open requests
    onblocked_handler: ?typedefs.EventHandler,
    onupgradeneeded_handler: ?typedefs.EventHandler,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    const state = instance.getState(StateType);

    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.open_request = null;
    internal.onblocked_handler = null;
    internal.onupgradeneeded_handler = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Getter for onblocked event handler
pub fn get_onblocked(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onblocked_handler orelse return error.InvalidState;
}

/// Getter for onupgradeneeded event handler
pub fn get_onupgradeneeded(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onupgradeneeded_handler orelse return error.InvalidState;
}

/// Setter for onblocked event handler
pub fn set_onblocked(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onblocked_handler = value;
}

/// Setter for onupgradeneeded event handler
pub fn set_onupgradeneeded(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onupgradeneeded_handler = value;
}
