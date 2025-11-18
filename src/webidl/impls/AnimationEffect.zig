//! Implementation for AnimationEffect interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AnimationEffect = @import("interfaces").AnimationEffect;

pub const State = AnimationEffect.State;

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

/// Getter for parent
pub fn get_parent(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for previousSibling
pub fn get_previousSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for nextSibling
pub fn get_nextSibling(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getTiming
pub fn call_getTiming(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getComputedTiming
pub fn call_getComputedTiming(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: updateTiming
pub fn call_updateTiming(instance: *runtime.Instance, timing: anyopaque) ImplError!void {
    _ = instance;
    _ = timing;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: before
pub fn call_before(instance: *runtime.Instance, effects: anyopaque) ImplError!void {
    _ = instance;
    _ = effects;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: after
pub fn call_after(instance: *runtime.Instance, effects: anyopaque) ImplError!void {
    _ = instance;
    _ = effects;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: replace
pub fn call_replace(instance: *runtime.Instance, effects: anyopaque) ImplError!void {
    _ = instance;
    _ = effects;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: remove
pub fn call_remove(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

