//! Implementation for InputDeviceCapabilities interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const InputDeviceCapabilities = @import("interfaces").InputDeviceCapabilities;

pub const State = InputDeviceCapabilities.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance, deviceInitDict: anyopaque) !void {
    _ = instance;
    _ = deviceInitDict;
    // TODO: Implement constructor logic
}

/// Getter for firesTouchEvents
pub fn get_firesTouchEvents(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for pointerMovementScrolls
pub fn get_pointerMovementScrolls(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

