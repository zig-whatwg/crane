//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for CSSNumericValue interface
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
const CSSNumericValue = interfaces.CSSNumericValue;

pub const State = CSSNumericValue.State;

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

/// Operation: equals
pub fn call_equals(instance: *runtime.Instance, value: []const typedefs.CSSNumberish) ImplError!bool {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: max
pub fn call_max(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: sub
pub fn call_sub(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: min
pub fn call_min(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: mul
pub fn call_mul(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: add
pub fn call_add(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: to
pub fn call_to(instance: *runtime.Instance, unit: runtime.USVString) ImplError!*runtime.Instance {
    _ = instance;
    _ = unit;
    return error.NotImplemented;
}

/// Operation: toSum
pub fn call_toSum(instance: *runtime.Instance, units: []const runtime.USVString) ImplError!*runtime.Instance {
    _ = instance;
    _ = units;
    return error.NotImplemented;
}

/// Operation: div
pub fn call_div(instance: *runtime.Instance, values: []const typedefs.CSSNumberish) ImplError!*runtime.Instance {
    _ = instance;
    _ = values;
    return error.NotImplemented;
}

/// Operation: type
pub fn call_type(instance: *runtime.Instance) ImplError!dictionaries.CSSNumericType {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: parse
pub fn call_parse(instance: *runtime.Instance, cssText: runtime.USVString) ImplError!*runtime.Instance {
    _ = instance;
    _ = cssText;
    return error.NotImplemented;
}

