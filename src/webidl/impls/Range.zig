//! Implementation for Range interface
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
const Range = interfaces.Range;

pub const State = Range.State;

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
pub fn get_commonAncestorContainer(instance: *runtime.Instance) ImplError!interfaces.Node {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStartBefore
pub fn call_setStartBefore(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: setEndBefore
pub fn call_setEndBefore(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: extractContents
pub fn call_extractContents(instance: *runtime.Instance) ImplError!interfaces.DocumentFragment {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: selectNode
pub fn call_selectNode(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: surroundContents
pub fn call_surroundContents(instance: *runtime.Instance, newParent: interfaces.Node) ImplError!void {
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
pub fn call_isPointInRange(instance: *runtime.Instance, node: interfaces.Node, offset: u32) ImplError!bool {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: setEndAfter
pub fn call_setEndAfter(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: insertNode
pub fn call_insertNode(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: setEnd
pub fn call_setEnd(instance: *runtime.Instance, node: interfaces.Node, offset: u32) ImplError!void {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: setStartAfter
pub fn call_setStartAfter(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: selectNodeContents
pub fn call_selectNodeContents(instance: *runtime.Instance, node: interfaces.Node) ImplError!void {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: createContextualFragment
pub fn call_createContextualFragment(instance: *runtime.Instance, string: *const anyopaque) ImplError!interfaces.DocumentFragment {
    _ = instance;
    _ = string;
    return error.NotImplemented;
}

/// Operation: collapse
pub fn call_collapse(instance: *runtime.Instance, toStart: bool) ImplError!void {
    _ = instance;
    _ = toStart;
    return error.NotImplemented;
}

/// Operation: comparePoint
pub fn call_comparePoint(instance: *runtime.Instance, node: interfaces.Node, offset: u32) ImplError!i16 {
    _ = instance;
    _ = node;
    _ = offset;
    return error.NotImplemented;
}

/// Operation: getClientRects
pub fn call_getClientRects(instance: *runtime.Instance) ImplError!interfaces.DOMRectList {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cloneRange
pub fn call_cloneRange(instance: *runtime.Instance) ImplError!interfaces.Range {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: setStart
pub fn call_setStart(instance: *runtime.Instance, node: interfaces.Node, offset: u32) ImplError!void {
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
pub fn call_getBoundingClientRect(instance: *runtime.Instance) ImplError!interfaces.DOMRect {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: cloneContents
pub fn call_cloneContents(instance: *runtime.Instance) ImplError!interfaces.DocumentFragment {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: intersectsNode
pub fn call_intersectsNode(instance: *runtime.Instance, node: interfaces.Node) ImplError!bool {
    _ = instance;
    _ = node;
    return error.NotImplemented;
}

/// Operation: compareBoundaryPoints
pub fn call_compareBoundaryPoints(instance: *runtime.Instance, how: u16, sourceRange: interfaces.Range) ImplError!i16 {
    _ = instance;
    _ = how;
    _ = sourceRange;
    return error.NotImplemented;
}

