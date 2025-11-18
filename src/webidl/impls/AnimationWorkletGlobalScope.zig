//! Implementation for AnimationWorkletGlobalScope interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const AnimationWorkletGlobalScope = @import("interfaces").AnimationWorkletGlobalScope;

pub const State = AnimationWorkletGlobalScope.State;

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

/// Operation: registerAnimator
pub fn call_registerAnimator(instance: *runtime.Instance, name: runtime.DOMString, animatorCtor: anyopaque) ImplError!void {
    _ = instance;
    _ = name;
    _ = animatorCtor;
    // TODO: Implement operation
    return error.NotImplemented;
}

