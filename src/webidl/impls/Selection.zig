//! Implementation for Selection interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Selection = @import("interfaces").Selection;

pub const State = Selection.State;

pub const ImplError = error{
    NotImplemented,
};

/// Initialize instance
pub fn init(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Initialize your instance state here
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance;
    // TODO: Clean up your instance resources here
}

/// Getter for anchorNode
pub fn get_anchorNode(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for anchorOffset
pub fn get_anchorOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for focusNode
pub fn get_focusNode(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for focusOffset
pub fn get_focusOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for isCollapsed
pub fn get_isCollapsed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for rangeCount
pub fn get_rangeCount(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for direction
pub fn get_direction(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: getRangeAt
pub fn call_getRangeAt(instance: *runtime.Instance, index: u32) ImplError!anyopaque {
    _ = instance;
    _ = index;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: addRange
pub fn call_addRange(instance: *runtime.Instance, range: anyopaque) ImplError!void {
    _ = instance;
    _ = range;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeRange
pub fn call_removeRange(instance: *runtime.Instance, range: anyopaque) ImplError!void {
    _ = instance;
    _ = range;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: removeAllRanges
pub fn call_removeAllRanges(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: empty
pub fn call_empty(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getComposedRanges
pub fn call_getComposedRanges(instance: *runtime.Instance, options: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = options;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setPosition
pub fn call_setPosition(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: collapseToStart
pub fn call_collapseToStart(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: collapseToEnd
pub fn call_collapseToEnd(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: extend
pub fn call_extend(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setBaseAndExtent
pub fn call_setBaseAndExtent(instance: *runtime.Instance, anchorNode: anyopaque, anchorOffset: u32, focusNode: anyopaque, focusOffset: u32) ImplError!void {
    _ = instance;
    _ = anchorNode;
    _ = anchorOffset;
    _ = focusNode;
    _ = focusOffset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectAllChildren
pub fn call_selectAllChildren(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: modify
pub fn call_modify(instance: *runtime.Instance, alter: runtime.DOMString, direction: runtime.DOMString, granularity: runtime.DOMString) ImplError!void {
    _ = instance;
    _ = alter;
    _ = direction;
    _ = granularity;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteFromDocument
pub fn call_deleteFromDocument(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: containsNode
pub fn call_containsNode(instance: *runtime.Instance, node: anyopaque, allowPartialContainment: bool) ImplError!bool {
    _ = instance;
    _ = node;
    _ = allowPartialContainment;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

