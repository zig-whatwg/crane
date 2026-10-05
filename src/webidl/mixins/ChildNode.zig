//! Auto-generated mixin: ChildNode
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ChildNodeImpl = @import("impls").ChildNode;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").ChildNode;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ChildNode")) {
        if (comptime @hasDecl(impls.ChildNode, "installHooks")) impls.ChildNode.installHooks();
    }
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(instance);

    return try ChildNodeImpl.call_before(instance, nodes);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(instance);

    return try ChildNodeImpl.call_replaceWith(instance, nodes);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_remove(instance: *runtime.Instance) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(instance);

    return try ChildNodeImpl.call_remove(instance);
}

/// Extended attributes: [CEReactions], [Unscopable]
pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(instance);

    return try ChildNodeImpl.call_after(instance, nodes);
}
