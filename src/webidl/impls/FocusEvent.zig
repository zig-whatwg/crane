//! Implementation for FocusEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-focusevent
//!
//! ```idl
//! [Exposed=Window]
//! interface FocusEvent : UIEvent {
//!   constructor(DOMString type, optional FocusEventInit eventInitDict = {});
//!   readonly attribute EventTarget? relatedTarget;
//! };
//! dictionary FocusEventInit : UIEventInit {
//!   EventTarget? relatedTarget = null;
//! };
//! ```

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const event_construction = @import("dom").event_construction;
const same_object = @import("same_object.zig");
const FocusEvent = interfaces.FocusEvent;

pub const State = FocusEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The related target, as a generation-checked link: an element that loses
/// focus to another can be removed and collected while script keeps the
/// event, and the link then reads null rather than a recycled slot.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    related_target: ?same_object.Link = null,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: the UIEvent part, then FocusEvent's own state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the UIEvent part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.UIEvent.deinit(instance);
}

/// Constructor: inner event creation steps, UIEventInit's members, then
/// relatedTarget.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.FocusEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &FocusEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.FocusEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base.base));
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(dict.base));
    setRelatedTarget(instance, dict.relatedTarget);
    return instance;
}

/// Set the related target an engine-fired focus event reports.
pub fn setRelatedTarget(instance: *runtime.Instance, target: ?*runtime.Instance) void {
    const internal = getInternal(instance) orelse return;
    internal.related_target = if (target) |t| same_object.Link.to(t) else null;
}

/// Getter for relatedTarget: the value it was initialized to, while that
/// object lives.
pub fn get_relatedTarget(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const link = internal.related_target orelse return null;
    if (!link.isLive()) return null;
    return link.instance;
}
