//! Implementation for CanvasPathDrawingStyles interface
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
const CanvasPathDrawingStyles = interfaces.CanvasPathDrawingStyles;

pub const State = CanvasPathDrawingStyles.State;

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

/// Getter for lineWidth
pub fn get_lineWidth(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineCap
pub fn get_lineCap(instance: *runtime.Instance) ImplError!enums.CanvasLineCap {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineJoin
pub fn get_lineJoin(instance: *runtime.Instance) ImplError!enums.CanvasLineJoin {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for miterLimit
pub fn get_miterLimit(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for lineDashOffset
pub fn get_lineDashOffset(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for lineWidth
pub fn set_lineWidth(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineCap
pub fn set_lineCap(instance: *runtime.Instance, value: enums.CanvasLineCap) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineJoin
pub fn set_lineJoin(instance: *runtime.Instance, value: enums.CanvasLineJoin) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for miterLimit
pub fn set_miterLimit(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for lineDashOffset
pub fn set_lineDashOffset(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getLineDash
pub fn call_getLineDash(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setLineDash
pub fn call_setLineDash(instance: *runtime.Instance, segments: *const anyopaque) ImplError!void {
    _ = instance;
    _ = segments;
    return error.NotImplemented;
}

