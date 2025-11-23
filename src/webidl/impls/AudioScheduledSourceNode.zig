//! Implementation for AudioScheduledSourceNode interface
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
const AudioScheduledSourceNode = interfaces.AudioScheduledSourceNode;

pub const State = AudioScheduledSourceNode.State;

pub const ImplError = error{
    NotImplemented,
};

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

/// Getter for onended
pub fn get_onended(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for onended
pub fn set_onended(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: stop
pub fn call_stop(instance: *runtime.Instance, when: f64) ImplError!void {
    _ = instance;
    _ = when;
    return error.NotImplemented;
}

/// Operation: start
pub fn call_start(instance: *runtime.Instance, when: f64) ImplError!void {
    _ = instance;
    _ = when;
    return error.NotImplemented;
}

