//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for InterestGroupReportingScriptRunnerGlobalScope interface
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
const InterestGroupReportingScriptRunnerGlobalScope = interfaces.InterestGroupReportingScriptRunnerGlobalScope;

pub const State = InterestGroupReportingScriptRunnerGlobalScope.State;

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

/// Operation: registerAdMacro
pub fn call_registerAdMacro(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = name;
    _ = value;
    return error.NotImplemented;
}

/// Operation: registerAdBeacon
pub fn call_registerAdBeacon(instance: *runtime.Instance, map: *const anyopaque) ImplError!void {
    _ = instance;
    _ = map;
    return error.NotImplemented;
}

/// Operation: sendReportTo
pub fn call_sendReportTo(instance: *runtime.Instance, url: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = url;
    return error.NotImplemented;
}

