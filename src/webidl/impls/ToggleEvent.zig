//! Implementation for ToggleEvent interface
//!
//! Spec: HTML Standard § 6.5.1 The ToggleEvent interface
//! https://html.spec.whatwg.org/multipage/interaction.html#the-toggleevent-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface ToggleEvent : Event {
//!   constructor(DOMString type, optional ToggleEventInit eventInitDict = {});
//!   readonly attribute DOMString oldState;
//!   readonly attribute DOMString newState;
//!   readonly attribute Element? source;
//! };
//!
//! dictionary ToggleEventInit : EventInit {
//!   DOMString oldState = "";
//!   DOMString newState = "";
//!   Element? source = null;
//! };
//! ```
//!
//! Fired by a details element's toggle task (HTMLDetailsElement.zig) and by
//! popovers and dialogs, and constructed by script.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const EventImpl = @import("Event.zig");
const same_object = @import("same_object.zig");
const ToggleEvent = interfaces.ToggleEvent;

pub const State = ToggleEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// "The oldState and newState attributes must return the values they are
/// initialized to" - and source is initialized the same way, then retargeted
/// by its getter.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned copies.
    old_state: []u8 = &.{},
    new_state: []u8 = &.{},
    /// The source element, as a generation-checked link rather than a pin.
    /// Blink traces `source_` from the event (ToggleEvent::Trace); Crane has
    /// no tracing, and a strong pin would make an element whose listener
    /// keeps its event (`el.last = e`) a cycle of strong handles that holds
    /// the page. The link reads null only once the element itself is
    /// collected - nothing, no tree and no script, refers to it any more.
    source: ?same_object.Link = null,

    fn clear(self: *InternalState) void {
        self.allocator.free(self.old_state);
        self.allocator.free(self.new_state);
        self.old_state = &.{};
        self.new_state = &.{};
        self.source = null;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.clear();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// each ToggleEventInit member (oldState and newState default to "", source
/// to null).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ToggleEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &ToggleEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.ToggleEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try EventImpl.innerEventCreationSteps(instance, @"type", dict.base);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    const old_state = try allocator.dupe(u8, if (dict.oldState) |v| v.asSlice() else "");
    errdefer allocator.free(old_state);
    const new_state = try allocator.dupe(u8, if (dict.newState) |v| v.asSlice() else "");
    internal.clear();
    internal.old_state = old_state;
    internal.new_state = new_state;
    internal.source = if (dict.source) |element| same_object.Link.to(element) else null;
    return instance;
}

/// Getter for oldState. A copy: the binding frees what a string getter
/// returns.
pub fn get_oldState(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initDupe(instance.ctx.allocator, "");
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.old_state);
}

/// Getter for newState. A copy, as oldState's.
pub fn get_newState(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initDupe(instance.ctx.allocator, "");
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.new_state);
}

/// Getter for source: "return the result of retargeting source against
/// this's currentTarget."
pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const link = internal.source orelse return null;
    if (!link.isLive()) return null;
    const current_target = try interfaces.Event.get_currentTarget(instance);
    return retarget(link.instance, current_target);
}

// ============================================================================
// DOM "retarget"
// ============================================================================

/// DOM "retarget A against B": repeat - if A is not a node, or A's root is
/// not a shadow root, or B is a node and A's root is a shadow-including
/// inclusive ancestor of B, return A; otherwise set A to A's root's host.
/// `a` is an Element here (source's type), so always a node.
///
/// Spec: https://dom.spec.whatwg.org/#retarget
fn retarget(a_given: *runtime.Instance, b: ?*runtime.Instance) !*runtime.Instance {
    var a = a_given;
    // A shadow root chain is a handful deep; the bound only stops a corrupt
    // tree from looping here.
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        const root = try rootOf(a);
        const host = shadowHostOf(root) orelse return a;
        if (b) |target| {
            if (isNode(target) and try isShadowIncludingInclusiveAncestor(root, target)) return a;
        }
        a = host;
    }
    return a;
}

fn isNode(target: *runtime.Instance) bool {
    return target.stateAs(interfaces.Node.State) != null;
}

fn rootOf(node: *runtime.Instance) !*runtime.Instance {
    return interfaces.Node.call_getRootNode(node, webidl.Opt(dictionaries.GetRootNodeOptions).notPassed());
}

/// `root`'s host when it is a shadow root; null for any other root.
fn shadowHostOf(root: *runtime.Instance) ?*runtime.Instance {
    if (root.stateAs(interfaces.ShadowRoot.State) == null) return null;
    return interfaces.ShadowRoot.get_host(root) catch null;
}

/// DOM: "An object A is a shadow-including inclusive ancestor of an object B,
/// if and only if A is B or A is a shadow-including ancestor of B" - an
/// inclusive ancestor of B, or of the host of each shadow root B's tree hangs
/// from.
fn isShadowIncludingInclusiveAncestor(ancestor: *runtime.Instance, node: *runtime.Instance) !bool {
    var current = node;
    var depth: usize = 0;
    while (depth < 64) : (depth += 1) {
        if (try interfaces.Node.call_contains(ancestor, current)) return true;
        current = shadowHostOf(try rootOf(current)) orelse return false;
    }
    return false;
}
