//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for GPUBuffer interface
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
const GPUBuffer = interfaces.GPUBuffer;

pub const State = GPUBuffer.State;

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

/// Getter for size
pub fn get_size(instance: *runtime.Instance) ImplError!typedefs.GPUSize64Out {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for usage
pub fn get_usage(instance: *runtime.Instance) ImplError!typedefs.GPUFlagsConstant {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for mapState
pub fn get_mapState(instance: *runtime.Instance) ImplError!enums.GPUBufferMapState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for label
pub fn get_label(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for label
pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: unmap
pub fn call_unmap(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getMappedRange
pub fn call_getMappedRange(instance: *runtime.Instance, offset: webidl.Opt(typedefs.GPUSize64), size: webidl.Opt(typedefs.GPUSize64)) ImplError!*const anyopaque {
    _ = instance;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: mapAsync
pub fn call_mapAsync(instance: *runtime.Instance, mode: typedefs.GPUMapModeFlags, offset: webidl.Opt(typedefs.GPUSize64), size: webidl.Opt(typedefs.GPUSize64)) ImplError!*const anyopaque {
    _ = instance;
    _ = mode;
    _ = offset;
    _ = size;
    return error.NotImplemented;
}

/// Operation: destroy
pub fn call_destroy(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

