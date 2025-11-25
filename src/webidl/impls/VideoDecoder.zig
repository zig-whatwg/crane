//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for VideoDecoder interface
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
const VideoDecoder = interfaces.VideoDecoder;

pub const State = VideoDecoder.State;

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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: dictionaries.VideoDecoderInit) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &VideoDecoder.vtable, ctx);
    errdefer deinit(instance);

    _ = init_data;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) ImplError!enums.CodecState {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for decodeQueueSize
pub fn get_decodeQueueSize(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for ondequeue
pub fn get_ondequeue(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for ondequeue
pub fn set_ondequeue(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: isConfigSupported
pub fn call_isConfigSupported(instance: *runtime.Instance, config: dictionaries.VideoDecoderConfig) ImplError!*const anyopaque {
    _ = instance;
    _ = config;
    return error.NotImplemented;
}

/// Operation: decode
pub fn call_decode(instance: *runtime.Instance, chunk: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = chunk;
    return error.NotImplemented;
}

/// Operation: reset
pub fn call_reset(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: configure
pub fn call_configure(instance: *runtime.Instance, config: dictionaries.VideoDecoderConfig) ImplError!void {
    _ = instance;
    _ = config;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: flush
pub fn call_flush(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

