//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for GeolocationSensor interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Add your implementation logic
//!   3. The impls/ directory is the canonical location for implementations
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
const GeolocationSensor = interfaces.GeolocationSensor;

pub const State = GeolocationSensor.State;

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

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: dictionaries.GeolocationSensorOptions) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &GeolocationSensor.vtable, ctx);
    errdefer deinit(instance);

    _ = options;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for latitude
pub fn get_latitude(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for longitude
pub fn get_longitude(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for altitude
pub fn get_altitude(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for accuracy
pub fn get_accuracy(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for altitudeAccuracy
pub fn get_altitudeAccuracy(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for heading
pub fn get_heading(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for speed
pub fn get_speed(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Operation: read
pub fn call_read(instance: *runtime.Instance, readOptions: dictionaries.ReadOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = readOptions;
    return error.NotImplemented;
}

