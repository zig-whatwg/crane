//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for Geolocation interface
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
const Geolocation = interfaces.Geolocation;

pub const State = Geolocation.State;

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

/// Operation: getCurrentPosition
pub fn call_getCurrentPosition(instance: *runtime.Instance, successCallback: callbacks.PositionCallback, errorCallback: ?callbacks.PositionErrorCallback, options: dictionaries.PositionOptions) ImplError!void {
    _ = instance;
    _ = successCallback;
    _ = errorCallback;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearWatch
pub fn call_clearWatch(instance: *runtime.Instance, watchId: i32) ImplError!void {
    _ = instance;
    _ = watchId;
    return error.NotImplemented;
}

/// Operation: watchPosition
pub fn call_watchPosition(instance: *runtime.Instance, successCallback: callbacks.PositionCallback, errorCallback: ?callbacks.PositionErrorCallback, options: dictionaries.PositionOptions) ImplError!i32 {
    _ = instance;
    _ = successCallback;
    _ = errorCallback;
    _ = options;
    return error.NotImplemented;
}

