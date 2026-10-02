//! Implementation for NavigationCurrentEntryChangeEvent interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-navigationcurrententrychangeevent-interface
//!
//! The currententrychange event the navigation API fires when its current
//! entry changes: navigationType - "push", "replace", "traverse", or null
//! for updateCurrentEntry() - and from, the entry that was current.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const NavigationCurrentEntryChangeEvent = interfaces.NavigationCurrentEntryChangeEvent;
const same_object = @import("same_object.zig");

pub const State = NavigationCurrentEntryChangeEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Keeps `from` alive for as long as the event's wrapper is: script can hold
/// the event after the navigation API has let that entry go. An edge, not a
/// root (same_object.Traced).
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    from_edge: same_object.Traced = .{ .slot = .{ .name = "from" } },
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: the Event part, its cloned type and inherited
/// internal state. `from` is borrowed - the navigation API keeps its entries.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.from_edge.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// navigationType and from from the dictionary.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.NavigationCurrentEntryChangeEventInit) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &NavigationCurrentEntryChangeEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = eventInitDict;
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.own._internal = null;

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

    state.own.navigationType = init_dict.navigationType;
    state.own.from = init_dict.from;
    const internal = try ctx.allocator.create(InternalState);
    internal.* = .{ .allocator = ctx.allocator };
    state.own._internal = internal;
    internal.from_edge.hold(instance, init_dict.from);

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);
    return instance;
}

/// Getter for navigationType
pub fn get_navigationType(instance: *runtime.Instance) anyerror!?enums.NavigationType {
    return instance.getState(State).own.navigationType;
}

/// Getter for from
pub fn get_from(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance.getState(State).own.from;
}
