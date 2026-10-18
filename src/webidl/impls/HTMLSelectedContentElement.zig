//! Implementation for HTMLSelectedContentElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLSelectedContentElement = interfaces.HTMLSelectedContentElement;
const dom = @import("dom");
const selected_content = @import("html").forms.selected_content;
const associated = @import("html").form_associated;

pub const State = HTMLSelectedContentElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Disabledness is derived from ancestors; no node pointer is cached.
pub const InternalState = struct {};

pub fn installHooks() void {
    dom.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    dom.mutation.registerRemovingStepsCallback(&removingSteps) catch {};
    dom.mutation.registerMovingStepsCallback(&movingSteps) catch {};
    dom.mutation.registerPostConnectionStepsCallback(&postConnectionSteps) catch {};
}

fn instanceOf(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != interfaces.Node.get_ELEMENT_NODE()) return null;
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return null));
    return if (instance.stateAs(State) != null) instance else null;
}

fn insertionSteps(node: *dom.NodeBase) void {
    selected_content.inserted(instanceOf(node) orelse return);
}

fn oldSelect(old_parent: ?*dom.NodeBase) ?*runtime.Instance {
    const instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(old_parent orelse return null) orelse return null));
    if (instance.stateAs(interfaces.HTMLSelectElement.State) != null) return instance;
    return selected_content.nearestSelect(instance);
}

fn removingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    _ = instanceOf(node) orelse return;
    if (oldSelect(old_parent)) |select| selected_content.refreshInterest(select);
}

fn movingSteps(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    selected_content.inserted(content);
    if (oldSelect(old_parent)) |select| selected_content.refreshInterest(select);
    // HTML moving steps 3 queue a microtask. Its unwrapped-node hold is
    // the shared lifetime dependency (row 52 Q9 / row 61 Q3(c)); cloning
    // synchronously here would expose the wrong mutation order.
}

fn postConnectionSteps(node: *dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    const select = selected_content.enabledSelect(content) orelse return;
    if (associated.hasAttribute(select, "multiple")) return;
    selected_content.updateOne(select, content) catch {};
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLSelectedContentElement.init(ctx.allocator, ctx);
    errdefer HTMLSelectedContentElement.deinit(instance);

    return instance;
}
