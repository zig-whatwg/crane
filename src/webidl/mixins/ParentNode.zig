//! Auto-generated mixin: ParentNode
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ParentNodeImpl = @import("impls").ParentNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").ParentNode;
pub const NodeOrString = impl.NodeOrString;

/// Extended attributes: [SameObject]
pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try ParentNodeImpl.get_children(instance);
}

pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try ParentNodeImpl.get_firstElementChild(instance);
}

pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try ParentNodeImpl.get_lastElementChild(instance);
}

pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    return try ParentNodeImpl.get_childElementCount(instance);
}

pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!?*runtime.Instance {
    return try ParentNodeImpl.call_querySelector(instance, selectors);
}

/// Extended attributes: [NewObject]
pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!*runtime.Instance {
    // [NewObject] - Caller owns the returned object

    return try ParentNodeImpl.call_querySelectorAll(instance, selectors);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    return try ParentNodeImpl.call_prepend(instance, nodes);
}

/// Extended attributes: [CEReactions]
pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    return try ParentNodeImpl.call_moveBefore(instance, node, child);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    return try ParentNodeImpl.call_append(instance, nodes);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    return try ParentNodeImpl.call_replaceChildren(instance, nodes);
}
