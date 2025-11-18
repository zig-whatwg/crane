//! Implementation for PaintWorkletGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const PaintWorkletGlobalScope = @import("interfaces").PaintWorkletGlobalScope;

pub const State = PaintWorkletGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for devicePixelRatio
pub fn get_devicePixelRatio(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: registerPaint
pub fn call_registerPaint(instance: *runtime.Instance, name: runtime.DOMString, paintCtor: anyopaque) ImplError!void {
    _ = instance;
    _ = name;
    _ = paintCtor;
    // TODO: Implement operation
    return error.NotImplemented;
}

