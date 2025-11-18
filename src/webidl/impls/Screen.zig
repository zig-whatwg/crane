//! Implementation for Screen interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Screen = @import("interfaces").Screen;

pub const State = Screen.State;

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

/// Getter for availWidth
pub fn get_availWidth(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for availHeight
pub fn get_availHeight(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for colorDepth
pub fn get_colorDepth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for pixelDepth
pub fn get_pixelDepth(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isExtended
pub fn get_isExtended(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for orientation
pub fn get_orientation(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

