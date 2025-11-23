//! Implementation for Selection interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const Selection = interfaces.Selection;

pub const State = Selection.State;

pub const ImplError = error{
    NotImplemented,
};

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
pub fn get_anchorNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for anchorOffset
pub fn get_anchorOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for focusNode
pub fn get_focusNode(instance: *runtime.Instance) ImplError!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
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
pub fn call_setPosition(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
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
pub fn call_getComposedRanges(instance: *runtime.Instance, options: dictionaries.GetComposedRangesOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = options;
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: extend
pub fn call_extend(instance: *runtime.Instance, node: *runtime.Instance, offset: u32) ImplError!void {
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
pub fn call_modify(instance: *runtime.Instance, alter: runtime.DOMString, direction: runtime.DOMString, granularity: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = alter;
    _ = direction;
    _ = granularity;
    return error.NotImplemented;
}

/// Operation: containsNode
pub fn call_containsNode(instance: *runtime.Instance, node: *runtime.Instance, allowPartialContainment: bool) ImplError!bool {
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

