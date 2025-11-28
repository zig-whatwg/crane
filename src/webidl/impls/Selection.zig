//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for Selection interface
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
const Selection = interfaces.Selection;

pub const State = Selection.State;

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

/// Getter for anchorNode
pub fn get_anchorNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for anchorOffset
pub fn get_anchorOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for focusNode
pub fn get_focusNode(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    _ = instance;
    return null;
}

/// Getter for focusOffset
pub fn get_focusOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for isCollapsed
pub fn get_isCollapsed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for rangeCount
pub fn get_rangeCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setPosition
pub fn call_setPosition(instance: *runtime.Instance, node: ?*runtime.Instance, offset: webidl.Opt(u32)) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: removeAllRanges
pub fn call_removeAllRanges(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: selectAllChildren
pub fn call_selectAllChildren(instance: *runtime.Instance, node: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: deleteFromDocument
pub fn call_deleteFromDocument(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: empty
pub fn call_empty(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: collapseToEnd
pub fn call_collapseToEnd(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: getComposedRanges
pub fn call_getComposedRanges(instance: *runtime.Instance, options: webidl.Opt(dictionaries.GetComposedRangesOptions)) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, node: ?*runtime.Instance, offset: webidl.Opt(u32)) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: extend
pub fn call_extend(instance: *runtime.Instance, node: *runtime.Instance, offset: webidl.Opt(u32)) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: collapseToStart
pub fn call_collapseToStart(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: addRange
pub fn call_addRange(instance: *runtime.Instance, range: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = range;
    return error.NotImplemented;
}

/// Operation: setBaseAndExtent
pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: *runtime.Instance, anchorOffset: u32, focusNode: *runtime.Instance, focusOffset: u32) ImplError!void {
    _ = instance;
    _ = anchorNode;
    _ = anchorOffset;
    _ = focusNode;
    _ = focusOffset;
    return error.NotImplemented;
}

/// Operation: getRangeAt
pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) ImplError!*runtime.Instance {
    _ = instance;
    _ = index;
    return error.NotImplemented;
}

/// Operation: modify
pub fn call_modify(instance: *runtime.Instance, alter: webidl.Opt(runtime.DOMString), direction: webidl.Opt(runtime.DOMString), granularity: webidl.Opt(runtime.DOMString)) ImplError!void {
    _ = instance;
    _ = alter;
    _ = direction;
    _ = granularity;
    return error.NotImplemented;
}

/// Operation: containsNode
pub fn call_containsNode(instance: *runtime.Instance, node: *runtime.Instance, allowPartialContainment: webidl.Opt(bool)) ImplError!bool {
    _ = instance;
    _ = node;
    _ = allowPartialContainment;
    return error.NotImplemented;
}

/// Operation: removeRange
pub fn call_removeRange(instance: *runtime.Instance, range: *runtime.Instance) ImplError!void {
    _ = instance;
    _ = range;
    return error.NotImplemented;
}

