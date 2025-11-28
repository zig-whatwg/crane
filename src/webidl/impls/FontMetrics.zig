//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for FontMetrics interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const FontMetrics = interfaces.FontMetrics;

pub const State = FontMetrics.State;

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
    runtime.Instance.deinit(instance);
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for advances
pub fn get_advances(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for boundingBoxLeft
pub fn get_boundingBoxLeft(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for boundingBoxRight
pub fn get_boundingBoxRight(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for emHeightAscent
pub fn get_emHeightAscent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for emHeightDescent
pub fn get_emHeightDescent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for boundingBoxAscent
pub fn get_boundingBoxAscent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for boundingBoxDescent
pub fn get_boundingBoxDescent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontBoundingBoxAscent
pub fn get_fontBoundingBoxAscent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fontBoundingBoxDescent
pub fn get_fontBoundingBoxDescent(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for dominantBaseline
pub fn get_dominantBaseline(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for baselines
pub fn get_baselines(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for fonts
pub fn get_fonts(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

