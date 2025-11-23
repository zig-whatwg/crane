//! Implementation for CanvasTransform interface
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
const CanvasTransform = interfaces.CanvasTransform;

pub const State = CanvasTransform.State;

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

/// Operation: resetTransform
pub fn call_resetTransform(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setTransform
pub fn call_setTransform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) ImplError!void {
    _ = instance;
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    _ = e;
    _ = f;
    return error.NotImplemented;
}

/// Operation: getTransform
pub fn call_getTransform(instance: *runtime.Instance) ImplError!interfaces.DOMMatrix {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: transform
pub fn call_transform(instance: *runtime.Instance, a: f64, b: f64, c: f64, d: f64, e: f64, f: f64) ImplError!void {
    _ = instance;
    _ = a;
    _ = b;
    _ = c;
    _ = d;
    _ = e;
    _ = f;
    return error.NotImplemented;
}

/// Operation: rotate
pub fn call_rotate(instance: *runtime.Instance, angle: f64) ImplError!void {
    _ = instance;
    _ = angle;
    return error.NotImplemented;
}

/// Operation: scale
pub fn call_scale(instance: *runtime.Instance, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

/// Operation: translate
pub fn call_translate(instance: *runtime.Instance, x: f64, y: f64) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    return error.NotImplemented;
}

