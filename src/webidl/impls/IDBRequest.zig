//! Implementation for IDBRequest interface
//!
//! Connects WebIDL IDBRequest interface to storage.indexeddb.IDBRequest implementation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const IDBRequestInterface = interfaces.IDBRequest;

// Backend types
const BackendRequest = storage.indexeddb.IDBRequest;
const BackendReadyState = storage.indexeddb.IDBRequestReadyState;

pub const State = IDBRequestInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBRequest
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    request: ?*BackendRequest,
    source_instance: ?*runtime.Instance,
    transaction_instance: ?*runtime.Instance,

    // Event handlers
    onsuccess_handler: ?typedefs.EventHandler,
    onerror_handler: ?typedefs.EventHandler,

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
    internal.request = null;
    internal.source_instance = null;
    internal.transaction_instance = null;
    internal.onsuccess_handler = null;
    internal.onerror_handler = null;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Getter for result - throws InvalidStateError if request is pending
pub fn get_result(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const request = internal.request orelse return error.InvalidState;

    // Per spec: throw InvalidStateError if done flag is false
    const result = request.getResult() catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        else => return error.NotImplemented,
    };

    if (result) |res| {
        // Return result as opaque pointer based on type
        return switch (res) {
            .database => |db| @ptrCast(db),
            .key => |key| @ptrCast(&key),
            .value => |v| @ptrCast(v.ptr),
            .cursor => |c| @ptrCast(c),
            .count => |cnt| @ptrCast(&cnt),
            .keys => |ks| @ptrCast(ks.ptr),
            .values => |vs| @ptrCast(vs.ptr),
            .undefined => return error.InvalidState,
        };
    }

    return error.InvalidState;
}

/// Getter for error - throws InvalidStateError if request is pending
pub fn get_error(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const request = internal.request orelse return error.InvalidState;

    // Per spec: throw InvalidStateError if done flag is false
    _ = request.getError() catch |err| switch (err) {
        error.InvalidStateError => return error.InvalidState,
        else => return error.NotImplemented,
    };

    // Would return a DOMException instance if there's an error
    return null;
}

/// Getter for source - returns the object store, index, or cursor that generated the request
pub fn get_source(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    if (internal.source_instance) |src| {
        return @ptrCast(src);
    }
    return error.InvalidState;
}

/// Getter for transaction - returns the transaction that generated the request
pub fn get_transaction(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.transaction_instance;
}

/// Getter for readyState - returns "pending" or "done"
pub fn get_readyState(instance: *runtime.Instance) ImplError!enums.IDBRequestReadyState {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const request = internal.request orelse return error.InvalidState;

    return switch (request.ready_state) {
        .pending => ._pending_,
        .done => ._done_,
    };
}

/// Getter for onsuccess event handler
pub fn get_onsuccess(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onsuccess_handler orelse return error.InvalidState;
}

/// Getter for onerror event handler
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.onerror_handler orelse return error.InvalidState;
}

/// Setter for onsuccess event handler
pub fn set_onsuccess(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onsuccess_handler = value;
}

/// Setter for onerror event handler
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    internal.onerror_handler = value;
}
