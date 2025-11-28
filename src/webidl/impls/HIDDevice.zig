//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for HIDDevice interface
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
const HIDDevice = interfaces.HIDDevice;

pub const State = HIDDevice.State;

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

/// Getter for oninputreport
pub fn get_oninputreport(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for opened
pub fn get_opened(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for vendorId
pub fn get_vendorId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for productId
pub fn get_productId(instance: *runtime.Instance) ImplError!u16 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for productName
pub fn get_productName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for collections
pub fn get_collections(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for oninputreport
pub fn set_oninputreport(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: forget
pub fn call_forget(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: open
pub fn call_open(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: sendFeatureReport
pub fn call_sendFeatureReport(instance: *runtime.Instance, reportId: u8, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = reportId;
    _ = data;
    return error.NotImplemented;
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: receiveFeatureReport
pub fn call_receiveFeatureReport(instance: *runtime.Instance, reportId: u8) ImplError!*const anyopaque {
    _ = instance;
    _ = reportId;
    return error.NotImplemented;
}

/// Operation: sendReport
pub fn call_sendReport(instance: *runtime.Instance, reportId: u8, data: typedefs.BufferSource) ImplError!*const anyopaque {
    _ = instance;
    _ = reportId;
    _ = data;
    return error.NotImplemented;
}

