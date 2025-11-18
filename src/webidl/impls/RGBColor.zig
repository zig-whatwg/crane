//! Implementation for RGBColor interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const RGBColor = @import("interfaces").RGBColor;

pub const State = RGBColor.State;

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

/// Getter for red
pub fn get_red(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for green
pub fn get_green(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for blue
pub fn get_blue(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

