//! Implementation for Gamepad interface
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
const Gamepad = interfaces.Gamepad;

pub const State = Gamepad.State;

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

/// Getter for id
pub fn get_id(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for index
pub fn get_index(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for connected
pub fn get_connected(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timestamp
pub fn get_timestamp(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mapping
pub fn get_mapping(instance: *runtime.Instance) ImplError!enums.GamepadMappingType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for axes
pub fn get_axes(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for buttons
pub fn get_buttons(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for touches
pub fn get_touches(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vibrationActuator
pub fn get_vibrationActuator(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hand
pub fn get_hand(instance: *runtime.Instance) ImplError!enums.GamepadHand {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hapticActuators
pub fn get_hapticActuators(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pose
pub fn get_pose(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

