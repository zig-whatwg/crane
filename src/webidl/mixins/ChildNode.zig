//! Auto-generated mixin: ChildNode
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ChildNodeImpl = @import("impls").ChildNode;

// Re-export types from impl
pub const impl = @import("impls").ChildNode;

pub fn call_before(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ChildNodeImpl.call_before(instance, nodes);
}

pub fn call_replaceWith(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ChildNodeImpl.call_replaceWith(instance, nodes);
}

pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    return ChildNodeImpl.call_remove(instance);
}

pub fn call_after(instance: *runtime.Instance, nodes: runtime.JSValue) anyerror!void {
    return ChildNodeImpl.call_after(instance, nodes);
}

