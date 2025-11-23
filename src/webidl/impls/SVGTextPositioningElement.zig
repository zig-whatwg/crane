//! Implementation for SVGTextPositioningElement interface
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
const SVGTextPositioningElement = interfaces.SVGTextPositioningElement;

pub const State = SVGTextPositioningElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for this implementation
/// Can be used to store browser-specific data structures
pub const InternalState = struct {};

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

/// Getter for x
pub fn get_x(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLengthList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLengthList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for dx
pub fn get_dx(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLengthList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for dy
pub fn get_dy(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLengthList {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rotate
pub fn get_rotate(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedNumberList {
    _ = instance;
    return error.NotImplemented;
}

