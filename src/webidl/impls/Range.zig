//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for Range interface
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
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const Range = interfaces.Range;

pub const State = Range.State;

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
    const instance = try init(allocator, State, &Range.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Getter for commonAncestorContainer
pub fn get_commonAncestorContainer(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStartBefore
pub fn call_setStartBefore(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: setEndBefore
pub fn call_setEndBefore(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: extractContents
pub fn call_extractContents(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: selectNode
pub fn call_selectNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: surroundContents
pub fn call_surroundContents(instance: *runtime.Instance, newParent: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = newParent;
    return error.NotImplemented;
}

/// Operation: detach
pub fn call_detach(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: isPointInRange
pub fn call_isPointInRange(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!bool {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: setEndAfter
pub fn call_setEndAfter(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: insertNode
pub fn call_insertNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: setEnd
pub fn call_setEnd(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: setStartAfter
pub fn call_setStartAfter(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: selectNodeContents
pub fn call_selectNodeContents(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: createContextualFragment
pub fn call_createContextualFragment(instance: *runtime.Instance, string: runtime.DOMString) ImplError!*runtime.Instance {
    _ = instance;
    _ = string;
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, toStart: webidl.Opt(bool)) ImplError!void {
    _ = instance;
    _ = toStart;
    return error.NotImplemented;
}

/// Operation: comparePoint
pub fn call_comparePoint(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!i16 {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: getClientRects
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cloneRange
pub fn call_cloneRange(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStart
pub fn call_setStart(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: deleteContents
pub fn call_deleteContents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getBoundingClientRect
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cloneContents
pub fn call_cloneContents(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: intersectsNode
pub fn call_intersectsNode(instance: *runtime.Instance, node: *runtime.Instance) ImplError!bool {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: compareBoundaryPoints
pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: *runtime.Instance) ImplError!i16 {
    _ = instance;
    _ = how;
    _ = sourceRange;
    return error.NotImplemented;
}

