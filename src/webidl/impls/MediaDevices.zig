//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for MediaDevices interface
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
const MediaDevices = interfaces.MediaDevices;

pub const State = MediaDevices.State;

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

/// Getter for ondevicechange
pub fn get_ondevicechange(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for oncaptureaction
pub fn get_oncaptureaction(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for ondevicechange
pub fn set_ondevicechange(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for oncaptureaction
pub fn set_oncaptureaction(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: selectAudioOutput
pub fn call_selectAudioOutput(instance: *runtime.Instance, options: dictionaries.AudioOutputOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getDisplayMedia
pub fn call_getDisplayMedia(instance: *runtime.Instance, options: dictionaries.DisplayMediaStreamOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: getUserMedia
pub fn call_getUserMedia(instance: *runtime.Instance, constraints: dictionaries.MediaStreamConstraints) ImplError!*const anyopaque {
    _ = instance;
    _ = constraints;
    return error.NotImplemented;
}

/// Operation: enumerateDevices
pub fn call_enumerateDevices(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getSupportedConstraints
pub fn call_getSupportedConstraints(instance: *runtime.Instance) ImplError!dictionaries.MediaTrackSupportedConstraints {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getViewportMedia
pub fn call_getViewportMedia(instance: *runtime.Instance, options: dictionaries.DisplayMediaStreamOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: setSupportedCaptureActions
pub fn call_setSupportedCaptureActions(instance: *runtime.Instance, actions: *const anyopaque) ImplError!void {
    _ = instance;
    _ = actions;
    return error.NotImplemented;
}

/// Operation: setCaptureHandleConfig
pub fn call_setCaptureHandleConfig(instance: *runtime.Instance, config: dictionaries.CaptureHandleConfig) ImplError!void {
    _ = instance;
    _ = config;
    return error.NotImplemented;
}

