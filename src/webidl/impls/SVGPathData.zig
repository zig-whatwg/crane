//! Implementation for SVGPathData interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const SVGPathData = @import("interfaces").SVGPathData;

pub const State = SVGPathData.State;

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

/// Operation: getPathData
pub fn call_getPathData(instance: *runtime.Instance, settings: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = settings;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPathData
pub fn call_setPathData(instance: *runtime.Instance, pathData: anyopaque) ImplError!void {
    _ = instance;
    _ = pathData;
    // TODO: Implement operation
    return error.NotImplemented;
}

