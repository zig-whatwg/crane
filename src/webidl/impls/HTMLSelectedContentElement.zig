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

/// HTML 4.10.17: every selectedcontent element has a boolean disabled,
/// initially false, and a cached select, initially null; both are updated
/// whenever it or an ancestor is inserted, removed or moved. The cached
/// select is a weak reference: it names the select, never keeps it.
pub const InternalState = struct {
    disabled: bool = false,
    cached_select: ?WeakNode = null,
};

const WeakNode = dom.refcount.WeakRef(dom.NodeBase);

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

/// The cached select while it lives: by its slab generation, then through
/// the instance bridge, which forgets a node in Node.deinit before its
/// NodeBase is freed (MutationObserver's liveNode; lesson
/// debugging-a-nodes-slab-generation-can-outlive-its-nodebase.md).
fn cachedSelect(content: *runtime.Instance) ?*runtime.Instance {
    const internal = content.getState(State).own._internal orelse return null;
    const weak = internal.cached_select orelse return null;
    if (runtime.SlabAllocator.generationOf(weak.instance) != weak.generation) return null;
    const instance: *runtime.Instance = @constCast(weak.instance);
    _ = dom.instance_bridge.getNodeBase(instance) orelse return null;
    return instance;
}

/// HTML "recalculate a selectedcontent element's disabledness": sets the
/// disabled flag and the cached select (steps 2 and 4), and returns the
/// nearest ancestor select (step 5), whether or not it is disabled.
fn recalculate(content: *runtime.Instance) ?*runtime.Instance {
    const result = selected_content.disabledness(content);
    const internal = content.getState(State).own._internal orelse return result.select;
    internal.disabled = result.disabled;
    internal.cached_select = null;
    if (result.select) |select| if (dom.instance_bridge.getNodeBase(select)) |base| {
        internal.cached_select = WeakNode.of(base);
    };
    return result.select;
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

fn isConnected(node: *dom.NodeBase) bool {
    return node.is_connected;
}

/// The select a selectedcontent left: whether it still has one is the
/// select's fast-path scalar (selected_content.refreshInterest).
fn leftSelect(old: ?*runtime.Instance, new: ?*runtime.Instance) void {
    const select = old orelse return;
    if (select != new) selected_content.refreshInterest(select);
}

/// HTML selectedcontent insertion steps, given selectedcontent.
fn insertionSteps(node: *dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    const old = cachedSelect(content);
    // 1. Let select be the result of recalculate a selectedcontent
    // element's disabledness given selectedcontent.
    const select = recalculate(content);
    leftSelect(old, select);
    selected_content.inserted(content);
    // 2. If selectedcontent is not connected, then return.
    if (!isConnected(node)) return;
    // 3. If selectedcontent's disabled is true, select is null, or select
    // has the multiple attribute, then return.
    if (isDisabled(content)) return;
    const owner = select orelse return;
    if (associated.hasAttribute(owner, "multiple")) return;
    // 4. Queue an update of a select's descendant selectedcontent elements
    // given select.
    selected_content.queueUpdate(owner.ctx.allocator, owner) catch {};
}

/// HTML selectedcontent removing steps: recalculate a selectedcontent
/// element's disabledness given removedNode.
fn removingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    const old = cachedSelect(content);
    leftSelect(old, recalculate(content));
}

/// HTML selectedcontent moving steps, given movedNode.
fn movingSteps(node: *dom.NodeBase, _: ?*dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    // 1. Let oldSelect be movedNode's cached select.
    const old_select = cachedSelect(content);
    // 2. Let wasDisabled be movedNode's disabled.
    const was_disabled = isDisabled(content);
    // 3. Let select be the result of recalculate a selectedcontent
    // element's disabledness given movedNode.
    const select = recalculate(content);
    leftSelect(old_select, select);
    selected_content.inserted(content);
    // 4. If movedNode's disabled is true, select is null, or select has the
    // multiple attribute, then return.
    if (isDisabled(content)) return;
    const owner = select orelse return;
    if (associated.hasAttribute(owner, "multiple")) return;
    // 5. If wasDisabled is false and select is oldSelect, then return:
    // moving an ancestor of select does not change what movedNode reflects.
    if (!was_disabled and old_select == owner) return;
    // 6. Queue an update of a select's descendant selectedcontent elements
    // given select.
    selected_content.queueUpdate(owner.ctx.allocator, owner) catch {};
}

/// HTML selectedcontent post-connection steps, given selectedcontent.
fn postConnectionSteps(node: *dom.NodeBase) void {
    const content = instanceOf(node) orelse return;
    // 1. Let select be selectedcontent's cached select.
    // 2. If select is null or select's pending selectedcontent update is
    // false, then return.
    const select = cachedSelect(content) orelse return;
    if (!dom.form_controls.selectedcontentPending(select)) return;
    // 3. Update a select's descendant selectedcontent elements given select.
    selected_content.updateAll(select) catch {};
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLSelectedContentElement.init(ctx.allocator, ctx);
    errdefer HTMLSelectedContentElement.deinit(instance);

    return instance;
}
