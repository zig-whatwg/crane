//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for DocumentOrShadowRoot interface
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
const DocumentOrShadowRoot = interfaces.DocumentOrShadowRoot;

pub const State = DocumentOrShadowRoot.State;

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

/// Getter for customElementRegistry
pub fn get_customElementRegistry(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for fullscreenElement
pub fn get_fullscreenElement(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for pictureInPictureElement
pub fn get_pictureInPictureElement(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for pointerLockElement
pub fn get_pointerLockElement(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for styleSheets
pub fn get_styleSheets(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for adoptedStyleSheets
pub fn get_adoptedStyleSheets(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for activeElement
pub fn get_activeElement(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Setter for adoptedStyleSheets
pub fn set_adoptedStyleSheets(instance: *runtime.Instance, value: *const anyopaque) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Operation: getAnimations
pub fn call_getAnimations(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

