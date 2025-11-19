//! Implementation for AbstractRange interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AbstractRange = @import("interfaces").AbstractRange;

pub const State = AbstractRange.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance (delegates to runtime.Instance.init)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable);
    // TODO: Add custom initialization here if needed
    // const state = instance.getState(StateType);
    // state.* = .{}; // Initialize fields
    return instance;
}

/// Deinitialize instance (delegates to runtime.Instance.deinit)
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Add custom cleanup here if needed
    // const state = instance.getState(State);
    // Clean up fields...
    runtime.Instance.deinit(instance);
}

/// Getter for startContainer
pub fn get_startContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for startOffset
pub fn get_startOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for endContainer
pub fn get_endContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for endOffset
pub fn get_endOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for collapsed
pub fn get_collapsed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

