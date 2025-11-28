//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for HTMLFrameElement interface
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
const HTMLFrameElement = interfaces.HTMLFrameElement;

pub const State = HTMLFrameElement.State;

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
    const instance = try init(allocator, State, &HTMLFrameElement.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for name
pub fn get_name(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for scrolling
pub fn get_scrolling(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for src
pub fn get_src(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for frameBorder
pub fn get_frameBorder(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for longDesc
pub fn get_longDesc(instance: *runtime.Instance) ImplError!runtime.USVString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for noResize
pub fn get_noResize(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for contentDocument
pub fn get_contentDocument(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for contentWindow
pub fn get_contentWindow(instance: *runtime.Instance) ImplError!?typedefs.WindowProxy {
    _ = instance;
    return null;
}

/// Getter for marginHeight
pub fn get_marginHeight(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for marginWidth
pub fn get_marginWidth(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Setter for name
pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for scrolling
pub fn set_scrolling(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for src
pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for frameBorder
pub fn set_frameBorder(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for longDesc
pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for noResize
pub fn set_noResize(instance: *runtime.Instance, value: bool) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for marginHeight
pub fn set_marginHeight(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

/// Setter for marginWidth
pub fn set_marginWidth(instance: *runtime.Instance, value: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = value;
    return error.NotImplemented;
}

