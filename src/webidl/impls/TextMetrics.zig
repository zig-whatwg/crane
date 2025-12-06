//! Implementation for TextMetrics interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TextMetrics = interfaces.TextMetrics;

pub const State = TextMetrics.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
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
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for actualBoundingBoxLeft
pub fn get_actualBoundingBoxLeft(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for actualBoundingBoxRight
pub fn get_actualBoundingBoxRight(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontBoundingBoxAscent
pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontBoundingBoxDescent
pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for actualBoundingBoxAscent
pub fn get_actualBoundingBoxAscent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for actualBoundingBoxDescent
pub fn get_actualBoundingBoxDescent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for emHeightAscent
pub fn get_emHeightAscent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for emHeightDescent
pub fn get_emHeightDescent(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for hangingBaseline
pub fn get_hangingBaseline(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for alphabeticBaseline
pub fn get_alphabeticBaseline(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ideographicBaseline
pub fn get_ideographicBaseline(instance: *runtime.Instance) anyerror!f64 {
    _ = instance;
    return error.NotImplemented;
}
