//! Implementation for ImageTrack interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrack = @import("interfaces").ImageTrack;

pub const State = ImageTrack.State;

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

/// Getter for animated
pub fn get_animated(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for frameCount
pub fn get_frameCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for repetitionCount
pub fn get_repetitionCount(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for selected
pub fn get_selected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for selected
pub fn set_selected(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

