//! Implementation for XRInputSource interface
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
const XRInputSource = interfaces.XRInputSource;

pub const State = XRInputSource.State;

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

/// Getter for handedness
pub fn get_handedness(instance: *runtime.Instance) ImplError!enums.XRHandedness {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for targetRayMode
pub fn get_targetRayMode(instance: *runtime.Instance) ImplError!enums.XRTargetRayMode {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for targetRaySpace
pub fn get_targetRaySpace(instance: *runtime.Instance) ImplError!interfaces.XRSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for gripSpace
pub fn get_gripSpace(instance: *runtime.Instance) ImplError!interfaces.XRSpace {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for profiles
pub fn get_profiles(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for skipRendering
pub fn get_skipRendering(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for gamepad
pub fn get_gamepad(instance: *runtime.Instance) ImplError!interfaces.Gamepad {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hand
pub fn get_hand(instance: *runtime.Instance) ImplError!interfaces.XRHand {
    _ = instance;
    return error.NotImplemented;
}

