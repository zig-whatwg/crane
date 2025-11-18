//! Implementation for Range interface
//!
//! This file is AUTO-GENERATED on first creation.
//! Add your custom implementation here.

const std = @import("std");
const runtime = @import("runtime");
const Range = @import("interfaces").Range;

pub const State = Range.State;

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

/// Constructor implementation
pub fn constructor(instance: *runtime.Instance) !void {
    _ = instance;
    // TODO: Implement constructor logic
}

/// Getter for startContainer
pub fn get_startContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for startOffset
pub fn get_startOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for endContainer
pub fn get_endContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for endOffset
pub fn get_endOffset(instance: *runtime.Instance) ImplError!u32 {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for collapsed
pub fn get_collapsed(instance: *runtime.Instance) ImplError!bool {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Getter for commonAncestorContainer
pub fn get_commonAncestorContainer(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement getter
    return error.NotImplemented;
}

/// Operation: setStart
pub fn call_setStart(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setEnd
pub fn call_setEnd(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setStartBefore
pub fn call_setStartBefore(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setStartAfter
pub fn call_setStartAfter(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setEndBefore
pub fn call_setEndBefore(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: setEndAfter
pub fn call_setEndAfter(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, toStart: bool) ImplError!void {
    _ = instance;
    _ = toStart;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectNode
pub fn call_selectNode(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: selectNodeContents
pub fn call_selectNodeContents(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: compareBoundaryPoints
pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: anyopaque) ImplError!i16 {
    _ = instance;
    _ = how;
    _ = sourceRange;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: deleteContents
pub fn call_deleteContents(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: extractContents
pub fn call_extractContents(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cloneContents
pub fn call_cloneContents(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: insertNode
pub fn call_insertNode(instance: *runtime.Instance, node: anyopaque) ImplError!void {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: surroundContents
pub fn call_surroundContents(instance: *runtime.Instance, newParent: anyopaque) ImplError!void {
    _ = instance;
    _ = newParent;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: cloneRange
pub fn call_cloneRange(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: detach
pub fn call_detach(instance: *runtime.Instance) ImplError!void {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: isPointInRange
pub fn call_isPointInRange(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!bool {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: comparePoint
pub fn call_comparePoint(instance: *runtime.Instance, node: anyopaque, offset: u32) ImplError!i16 {
    _ = instance;
    _ = node;
    _ = offset;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: intersectsNode
pub fn call_intersectsNode(instance: *runtime.Instance, node: anyopaque) ImplError!bool {
    _ = instance;
    _ = node;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: unnamed
pub fn call_unnamed(instance: *runtime.Instance) ImplError!runtime.DOMString {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: createContextualFragment
pub fn call_createContextualFragment(instance: *runtime.Instance, string: anyopaque) ImplError!anyopaque {
    _ = instance;
    _ = string;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getClientRects
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

/// Operation: getBoundingClientRect
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!anyopaque {
    _ = instance;
    // TODO: Implement operation
    return error.NotImplemented;
}

