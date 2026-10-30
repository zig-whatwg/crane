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

/// HTML's flag survives removal until insertion/moving recalculates it.
pub const InternalState = struct { disabled: bool = false };

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

fn isDisabled(content: *runtime.Instance) bool {
    const state = content.stateAs(State) orelse return true;
    return if (state.own._internal) |internal| internal.disabled else false;
}

fn recalculate(content: *runtime.Instance) ?*runtime.Instance {
    const result = selected_content.disabledness(content);
    if (content.getState(State).own._internal) |internal| internal.disabled = result.disabled;
    return if (result.disabled) null else result.select;
}

pub fn installHooks() void {
    dom.selected_content.install(&isDisabled);
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
    const content = instanceOf(node) orelse return;
    _ = recalculate(content);
    selected_content.inserted(content);
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
    const select = recalculate(content) orelse return;
    if (associated.hasAttribute(select, "multiple")) return;
    // HTML moving steps 3: keep the captured select and content separately,
    // even if another move changes their relationship before this runs.
    selected_content.queueUpdate(content.ctx.allocator, select, content) catch {};
}

fn postConnectionSteps(node: *dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    const select = recalculate(content) orelse return;
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
