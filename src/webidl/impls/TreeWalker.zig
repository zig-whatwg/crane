//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for TreeWalker interface
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
const TreeWalker = interfaces.TreeWalker;

pub const State = TreeWalker.State;

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

/// Getter for root
pub fn get_root(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for whatToShow
pub fn get_whatToShow(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for filter
pub fn get_filter(instance: *runtime.Instance) ImplError!??*runtime.CallbackWrapper {
    _ = instance;
    return null;
}

/// Getter for currentNode
pub fn get_currentNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for currentNode
pub fn set_currentNode(instance: *runtime.Instance, value: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: parentNode
pub fn call_parentNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: previousNode
pub fn call_previousNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: lastChild
pub fn call_lastChild(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: nextNode
pub fn call_nextNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: firstChild
pub fn call_firstChild(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: previousSibling
pub fn call_previousSibling(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Operation: nextSibling
pub fn call_nextSibling(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

