//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for WebTransportDatagramDuplexStream interface
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
const WebTransportDatagramDuplexStream = interfaces.WebTransportDatagramDuplexStream;

pub const State = WebTransportDatagramDuplexStream.State;

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

/// Getter for readable
pub fn get_readable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for maxDatagramSize
pub fn get_maxDatagramSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for incomingMaxAge
pub fn get_incomingMaxAge(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for outgoingMaxAge
pub fn get_outgoingMaxAge(instance: *runtime.Instance) ImplError!?f64 {
    _ = instance;
    return null;
}

/// Getter for incomingHighWaterMark
pub fn get_incomingHighWaterMark(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for outgoingHighWaterMark
pub fn get_outgoingHighWaterMark(instance: *runtime.Instance) ImplError!f64 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for incomingMaxAge
pub fn set_incomingMaxAge(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for outgoingMaxAge
pub fn set_outgoingMaxAge(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for incomingHighWaterMark
pub fn set_incomingHighWaterMark(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for outgoingHighWaterMark
pub fn set_outgoingHighWaterMark(instance: *runtime.Instance, value: f64) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: createWritable
pub fn call_createWritable(instance: *runtime.Instance, options: dictionaries.WebTransportSendOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

