//! Implementation for SVGMaskElement interface
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
const SVGMaskElement = interfaces.SVGMaskElement;

pub const State = SVGMaskElement.State;

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

/// Getter for maskUnits
pub fn get_maskUnits(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedEnumeration {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maskContentUnits
pub fn get_maskContentUnits(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedEnumeration {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for x
pub fn get_x(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLength {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for y
pub fn get_y(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLength {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLength {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) ImplError!interfaces.SVGAnimatedLength {
    _ = instance;
    return error.NotImplemented;
}

