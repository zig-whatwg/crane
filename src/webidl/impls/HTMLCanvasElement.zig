//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for HTMLCanvasElement interface
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
const HTMLCanvasElement = interfaces.HTMLCanvasElement;

pub const State = HTMLCanvasElement.State;

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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &HTMLCanvasElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for width
pub fn get_width(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for height
pub fn get_height(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for width
pub fn set_width(instance: *runtime.Instance, value: u32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for height
pub fn set_height(instance: *runtime.Instance, value: u32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: captureStream
pub fn call_captureStream(instance: *runtime.Instance, frameRequestRate: f64) ImplError!*runtime.Instance {
    _ = instance;
    _ = frameRequestRate;
    return error.NotImplemented;
}

/// Operation: getContext
pub fn call_getContext(instance: *runtime.Instance, contextId: runtime.DOMString, options: *const anyopaque) ImplError!?typedefs.RenderingContext {
    _ = instance;
    _ = contextId;
    _ = options;
    return null;
}

/// Operation: toDataURL
pub fn call_toDataURL(instance: *runtime.Instance, @"type": runtime.DOMString, quality: *const anyopaque) ImplError!runtime.USVString {
    _ = instance;
    _ = @"type";
    _ = quality;
    return error.NotImplemented;
}

/// Operation: toBlob
pub fn call_toBlob(instance: *runtime.Instance, _callback: callbacks.BlobCallback, @"type": runtime.DOMString, quality: *const anyopaque) ImplError!void {
    _ = instance;
    _ = _callback;
    _ = @"type";
    _ = quality;
    return error.NotImplemented;
}

/// Operation: transferControlToOffscreen
pub fn call_transferControlToOffscreen(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

