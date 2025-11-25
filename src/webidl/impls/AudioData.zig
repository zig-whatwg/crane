//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for AudioData interface
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
const AudioData = interfaces.AudioData;

pub const State = AudioData.State;

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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: dictionaries.AudioDataInit) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &AudioData.vtable, ctx);
    errdefer deinit(instance);

    _ = init_data;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for format
pub fn get_format(instance: *runtime.Instance) ImplError!?enums.AudioSampleFormat {
    _ = instance;
    return null;
}

/// Getter for sampleRate
pub fn get_sampleRate(instance: *runtime.Instance) ImplError!f32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for numberOfFrames
pub fn get_numberOfFrames(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for numberOfChannels
pub fn get_numberOfChannels(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!u64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for timestamp
pub fn get_timestamp(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: allocationSize
pub fn call_allocationSize(instance: *runtime.Instance, options: dictionaries.AudioDataCopyToOptions) ImplError!u32 {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: copyTo
pub fn call_copyTo(instance: *runtime.Instance, destination: typedefs.AllowSharedBufferSource, options: dictionaries.AudioDataCopyToOptions) ImplError!void {
    _ = instance;
    _ = destination;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clone
pub fn call_clone(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

