//! Implementation for PageRevealEvent interface
//!
//! HTML Standard §7.2.7.5 - The PageRevealEvent interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-pagerevealevent-interface
//!
//! "The viewTransition attribute must return the value it was initialized
//! to." The ViewTransition it names is kept alive for as long as the event
//! is (same_object.zig).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const same_object = @import("same_object.zig");
const PageRevealEvent = interfaces.PageRevealEvent;

pub const State = PageRevealEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The pin that keeps viewTransition's object alive with the event.
pub const InternalState = struct {
    allocator: Allocator,
    view_transition_pin: same_object.Pin = .{},

    fn release(self: *InternalState) void {
        self.view_transition_pin.release();
    }
};

/// Initialize instance (creates the instance): the Event part is set by the
/// constructor.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: its pins, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.release();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// viewTransition from the dictionary.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.PageRevealEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &PageRevealEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.PageRevealEventInit{ .base = .{} };
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.own._internal = null;
    state.own.viewTransition = null;

    // DOM "inner event creation steps": the initialized flag, the type, and
    // each EventInit member initializing the attribute of its name.
    state.base.own.type = try @"type".clone(ctx.allocator);
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0; // NONE
    state.base.own.bubbles = init_dict.base.bubbles orelse false;
    state.base.own.cancelable = init_dict.base.cancelable orelse false;
    state.base.own.composed = init_dict.base.composed orelse false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;

    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator };
    state.own._internal = internal;
    state.own.viewTransition = init_dict.viewTransition;
    if (init_dict.viewTransition) |transition| internal.view_transition_pin.hold(transition);

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// "The viewTransition attribute must return the value it was initialized
/// to." Nothing makes a ViewTransition (no rendering), so only a constructed
/// event has one.
pub fn get_viewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return instance.getState(State).own.viewTransition;
}
