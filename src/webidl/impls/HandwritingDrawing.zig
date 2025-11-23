//! Implementation for HandwritingDrawing interface
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
const HandwritingDrawing = interfaces.HandwritingDrawing;

pub const State = HandwritingDrawing.State;

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

/// Operation: addStroke
pub fn call_addStroke(instance: *runtime.Instance, stroke: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = stroke;
    return error.NotImplemented;
}

/// Operation: getStrokes
pub fn call_getStrokes(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getPrediction
pub fn call_getPrediction(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: clear
pub fn call_clear(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: removeStroke
pub fn call_removeStroke(instance: *runtime.Instance, stroke: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = stroke;
    return error.NotImplemented;
}

