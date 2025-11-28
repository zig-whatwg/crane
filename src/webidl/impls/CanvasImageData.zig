//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for CanvasImageData interface
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
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const CanvasImageData = interfaces.CanvasImageData;

pub const State = CanvasImageData.State;

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

/// Operation: getImageData
pub fn call_getImageData(instance: *runtime.Instance, sx: i32, sy: i32, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) ImplError!*runtime.Instance {
    _ = instance;
    _ = sx;
    _ = sy;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
}

/// Operation: createImageData
pub fn call_createImageData(instance: *runtime.Instance, sw: i32, sh: i32, settings: webidl.Opt(dictionaries.ImageDataSettings)) ImplError!*runtime.Instance {
    _ = instance;
    _ = sw;
    _ = sh;
    _ = settings;
    return error.NotImplemented;
}

/// Operation: putImageData
pub fn call_putImageData(instance: *runtime.Instance, imageData: *runtime.Instance, dx: i32, dy: i32) ImplError!void {
    _ = instance;
    _ = imageData;
    _ = dx;
    _ = dy;
    return error.NotImplemented;
}

