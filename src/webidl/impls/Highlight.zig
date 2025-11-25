//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for Highlight interface
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
const Highlight = interfaces.Highlight;

pub const State = Highlight.State;

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
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, initialRanges: *runtime.Instance) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &Highlight.vtable, ctx);
    errdefer deinit(instance);

    _ = initialRanges;
    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for priority
pub fn get_priority(instance: *runtime.Instance) ImplError!i32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!enums.HighlightType {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for priority
pub fn set_priority(instance: *runtime.Instance, value: i32) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for type
pub fn set_type(instance: *runtime.Instance, value: enums.HighlightType) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

