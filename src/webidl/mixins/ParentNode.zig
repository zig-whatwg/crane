//! Auto-generated mixin: ParentNode
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ParentNodeImpl = @import("impls").ParentNode;

// Re-export types from impl
pub const impl = @import("impls").ParentNode;
pub const NodeOrString = impl.NodeOrString;

pub fn get_children(instance: *runtime.Instance) !*runtime.Instance {
    return ParentNodeImpl.get_children(instance);
}

pub fn get_firstElementChild(instance: *runtime.Instance) !?*runtime.Instance {
    return ParentNodeImpl.get_firstElementChild(instance);
}

pub fn get_lastElementChild(instance: *runtime.Instance) !?*runtime.Instance {
    return ParentNodeImpl.get_lastElementChild(instance);
}

pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
    return ParentNodeImpl.get_childElementCount(instance);
}

pub fn call_querySelector(instance: *runtime.Instance, selectors: typedefs.DOMString) !?*runtime.Instance {
    return ParentNodeImpl.call_querySelector(instance, selectors);
}

pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: typedefs.DOMString) !*runtime.Instance {
    return ParentNodeImpl.call_querySelectorAll(instance, selectors);
}

pub fn call_prepend(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ParentNodeImpl.call_prepend(instance, nodes);
}

pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
    return ParentNodeImpl.call_moveBefore(instance, node, child);
}

pub fn call_append(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ParentNodeImpl.call_append(instance, nodes);
}

pub fn call_replaceChildren(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ParentNodeImpl.call_replaceChildren(instance, nodes);
}

