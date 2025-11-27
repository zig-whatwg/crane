//! Implementation for NavigatorStorage interface (mixin)
//!
//! Exposes the StorageManager interface on Navigator.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const storage = @import("storage");
const NavigatorStorageInterface = interfaces.NavigatorStorage;

pub const State = NavigatorStorageInterface.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for NavigatorStorage
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    storage_manager_instance: ?*runtime.Instance,

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
    internal.storage_manager_instance = null;

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

/// Getter for storage - returns the StorageManager for this navigator
pub fn get_storage(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Return cached StorageManager instance if available
    if (internal.storage_manager_instance) |sm| {
        return sm;
    }

    // Create a new StorageManager instance
    const sm_instance = interfaces.StorageManager.init(internal.allocator, instance.ctx) catch {
        return error.OutOfMemory;
    };

    // Cache it
    internal.storage_manager_instance = sm_instance;
    return sm_instance;
}
