//! Implementation for SVGAnimatedNumber interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedNumber = @import("interfaces").SVGAnimatedNumber;

pub const State = SVGAnimatedNumber.State;

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

/// Getter for baseVal
pub fn get_baseVal(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for animVal
pub fn get_animVal(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Setter for baseVal
pub fn set_baseVal(instance: *runtime.Instance, value: f32) ImplError!void {
    _ = instance;
    _ = value;
    // TODO: Implement setter
    return error.NotImplemented;
}

