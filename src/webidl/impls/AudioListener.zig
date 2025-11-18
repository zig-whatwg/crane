//! Implementation for AudioListener interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AudioListener = @import("interfaces").AudioListener;

pub const State = AudioListener.State;

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

/// Getter for positionX
pub fn get_positionX(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for positionY
pub fn get_positionY(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for positionZ
pub fn get_positionZ(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for forwardX
pub fn get_forwardX(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for forwardY
pub fn get_forwardY(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for forwardZ
pub fn get_forwardZ(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for upX
pub fn get_upX(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for upY
pub fn get_upY(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for upZ
pub fn get_upZ(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: setPosition
pub fn call_setPosition(instance: *runtime.Instance, x: f32, y: f32, z: f32) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setOrientation
pub fn call_setOrientation(instance: *runtime.Instance, x: f32, y: f32, z: f32, xUp: f32, yUp: f32, zUp: f32) ImplError!void {
    _ = instance;
    _ = x;
    _ = y;
    _ = z;
    _ = xUp;
    _ = yUp;
    _ = zUp;
    // TODO: Implement operation
    return error.NotImplemented;
}

