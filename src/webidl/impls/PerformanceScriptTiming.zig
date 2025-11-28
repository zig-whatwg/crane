//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for PerformanceScriptTiming interface
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
const PerformanceScriptTiming = interfaces.PerformanceScriptTiming;

pub const State = PerformanceScriptTiming.State;

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

/// Getter for startTime
pub fn get_startTime(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for duration
pub fn get_duration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for entryType
pub fn get_entryType(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for invokerType
pub fn get_invokerType(instance: *runtime.Instance) ImplError!enums.ScriptInvokerType {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for invoker
pub fn get_invoker(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for executionStart
pub fn get_executionStart(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceURL
pub fn get_sourceURL(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceFunctionName
pub fn get_sourceFunctionName(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for sourceCharPosition
pub fn get_sourceCharPosition(instance: *runtime.Instance) ImplError!i64 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for pauseDuration
pub fn get_pauseDuration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for forcedStyleAndLayoutDuration
pub fn get_forcedStyleAndLayoutDuration(instance: *runtime.Instance) ImplError!typedefs.DOMHighResTimeStamp {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for window
pub fn get_window(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for windowAttribution
pub fn get_windowAttribution(instance: *runtime.Instance) ImplError!enums.ScriptWindowAttribution {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: toJSON
pub fn call_toJSON(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

