//! Implementation for ViewTransition interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ViewTransition = interfaces.ViewTransition;

pub const State = ViewTransition.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for updateCallbackDone
pub fn get_updateCallbackDone(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ready
pub fn get_ready(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for finished
pub fn get_finished(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for types
pub fn get_types(instance: *runtime.Instance) ImplError!interfaces.ViewTransitionTypeSet {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for transitionRoot
pub fn get_transitionRoot(instance: *runtime.Instance) ImplError!interfaces.Element {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for types
pub fn set_types(instance: *runtime.Instance, value: interfaces.ViewTransitionTypeSet) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: waitUntil
pub fn call_waitUntil(instance: *runtime.Instance, promise: *const anyopaque) ImplError!void {
    _ = instance;
    _ = promise;
    return error.NotImplemented;
}

/// Operation: skipTransition
pub fn call_skipTransition(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

