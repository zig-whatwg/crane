//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for LayoutFragment interface
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
const LayoutFragment = interfaces.LayoutFragment;

pub const State = LayoutFragment.State;

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

/// Getter for inlineSize
pub fn get_inlineSize(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for blockSize
pub fn get_blockSize(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for inlineOffset
pub fn get_inlineOffset(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for blockOffset
pub fn get_blockOffset(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for data
pub fn get_data(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for breakToken
pub fn get_breakToken(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for inlineOffset
pub fn set_inlineOffset(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for blockOffset
pub fn set_blockOffset(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

