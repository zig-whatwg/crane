//! Implementation for History interface
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
const History = interfaces.History;

pub const State = History.State;

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

/// Getter for length
pub fn get_length(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrollRestoration
pub fn get_scrollRestoration(instance: *runtime.Instance) ImplError!enums.ScrollRestoration {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for scrollRestoration
pub fn set_scrollRestoration(instance: *runtime.Instance, value: enums.ScrollRestoration) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: forward
pub fn call_forward(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: pushState
pub fn call_pushState(instance: *runtime.Instance, data: *const anyopaque, unused: runtime.DOMString, url: runtime.USVString) ImplError!void {
    _ = instance;
    _ = data;
    _ = unused;
    _ = url;
    return error.NotImplemented;
}

/// Operation: go
pub fn call_go(instance: *runtime.Instance, delta: i32) ImplError!void {
    _ = instance;
    _ = delta;
    return error.NotImplemented;
}

/// Operation: back
pub fn call_back(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: replaceState
pub fn call_replaceState(instance: *runtime.Instance, data: *const anyopaque, unused: runtime.DOMString, url: runtime.USVString) ImplError!void {
    _ = instance;
    _ = data;
    _ = unused;
    _ = url;
    return error.NotImplemented;
}

