//! Implementation for IDBVersionChangeEvent interface
//!
//! Represents a version change event in IndexedDB.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const webidl = @import("webidl");
const IDBVersionChangeEventInterface = interfaces.IDBVersionChangeEvent;

// Backend types
const BackendVersionChangeEvent = storage.indexeddb.IDBVersionChangeEvent;

pub const State = IDBVersionChangeEventInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state wrapping storage.indexeddb.IDBVersionChangeEvent
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    event: ?*BackendVersionChangeEvent,
    old_version: u64,
    new_version: ?u64,

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
    internal.event = null;
    internal.old_version = 0;
    internal.new_version = null;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.IDBVersionChangeEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &IDBVersionChangeEventInterface.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    const internal = state.own._internal.?;

    // Initialize from eventInitDict
    _ = @"type"; // Event type is handled by V8 Event prototype chain

    // Get values from eventInitDict if passed
    if (eventInitDict.wasPassed()) {
        internal.old_version = eventInitDict.value.oldVersion orelse 0;
        internal.new_version = eventInitDict.value.newVersion;
    } else {
        internal.old_version = 0;
        internal.new_version = null;
    }

    return instance;
}

/// Getter for oldVersion - returns the previous version of the database
pub fn get_oldVersion(instance: *runtime.Instance) ImplError!u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.old_version;
}

/// Getter for newVersion - returns the new version of the database (null if deleted)
pub fn get_newVersion(instance: *runtime.Instance) ImplError!?u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.new_version;
}
