//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for Origin interface
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
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const Origin = interfaces.Origin;

pub const State = Origin.State;

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

/// Deinitialize instance - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here - the GC integration
/// layer (gc_integration.onObjectFreed) handles freeing the slab after
/// calling this deinit function. Calling it here causes double-free.
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance's owned resources here (strings, arrays, etc.)
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
/// Note: Use ctx.allocator for all allocations to ensure consistency with deinit
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init() - use ctx.allocator for consistency with deinit
    const instance = try init(ctx.allocator, State, &Origin.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for opaque
pub fn get_opaque(instance: *runtime.Instance) anyerror!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isSameOrigin
pub fn call_isSameOrigin(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}

/// Static Operation: from
pub fn call_static_from(instance: *runtime.Instance, value: runtime.JSValue) anyerror!*runtime.Instance {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: isSameSite
pub fn call_isSameSite(instance: *runtime.Instance, other: *runtime.Instance) anyerror!bool {
    _ = instance;
    _ = other;
    return error.NotImplemented;
}
