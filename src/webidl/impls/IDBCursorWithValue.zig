//! Implementation for IDBCursorWithValue interface
//!
//! Extends IDBCursor with a `value` property that exposes the current record's value.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const IDBCursorWithValueInterface = interfaces.IDBCursorWithValue;

// Backend types
const BackendCursorWithValue = storage.indexeddb.IDBCursorWithValue;

pub const State = IDBCursorWithValueInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBCursorWithValue
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    cursor_with_value: ?*BackendCursorWithValue,
    request_instance: ?*runtime.Instance,

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
    internal.cursor_with_value = null;
    internal.request_instance = null;

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

/// Getter for value - returns the current record's value
pub fn get_value(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const cursor_with_value = internal.cursor_with_value orelse return error.InvalidState;

    // Get the value from the cursor
    if (cursor_with_value.getValue()) |value| {
        return @ptrCast(value.ptr);
    }

    return error.InvalidState;
}
