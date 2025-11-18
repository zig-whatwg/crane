//! Implementation for CropTarget interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const CropTarget = @import("interfaces").CropTarget;

pub const State = CropTarget.State;

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

/// Operation: fromElement
pub fn call_fromElement(instance: *runtime.Instance, element: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = element;
    // TODO: Implement operation
    return error.NotImplemented;
}

