//! Implementation for SubmitEvent interface
//!
//! Spec: HTML § 4.10.22.3 and "The SubmitEvent interface"
//! https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-submitevent-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface SubmitEvent : Event {
//!   constructor(DOMString type, optional SubmitEventInit eventInitDict = {});
//!   readonly attribute HTMLElement? submitter;
//! };
//! dictionary SubmitEventInit : EventInit {
//!   HTMLElement? submitter = null;
//! };
//! ```
//!
//! Fired by form submission (HTMLFormElement.zig) at the form, and
//! constructed by script.

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
const SubmitEvent = interfaces.SubmitEvent;

pub const State = SubmitEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The submitter, as a generation-checked link rather than a pin, as
/// ToggleEvent keeps its source: a strong hold from the event to a button
/// whose listener keeps the event would be a cycle of strong handles.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    submitter: ?same_object.Link = null,
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
    const instance = try interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
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
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps", then SubmitEventInit's
/// submitter (null by default).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.SubmitEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &SubmitEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.SubmitEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base));
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.submitter = if (dict.submitter) |element| same_object.Link.to(element) else null;
    return instance;
}

/// Getter for submitter: "the submitter attribute must return the value it
/// was initialized to" - while that element lives.
pub fn get_submitter(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const link = internal.submitter orelse return null;
    if (!link.isLive()) return null;
    return link.instance;
}
