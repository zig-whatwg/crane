//! Implementation for BeforeUnloadEvent interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-beforeunloadevent-interface
//!
//! `[Exposed=Window] interface BeforeUnloadEvent : Event { attribute DOMString
//! returnValue; };` - no constructor: the user agent makes one for "the steps
//! to fire beforeunload" (HTML 7.4.2.4), through `interfaces.BeforeUnloadEvent
//! .init` and then Event's `initEvent`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const BeforeUnloadEvent = interfaces.BeforeUnloadEvent;

pub const State = BeforeUnloadEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data. None: `returnValue`
/// lives in the generated state.
pub const InternalState = struct {};

/// Initialize instance (creates the instance), with the Event it is: an
/// initialized event with the empty type, which the caller names with
/// `initEvent`. The inherited Event state is made here - an event without it
/// cannot be dispatched (InvalidStateError).
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    const state = instance.getState(StateType);
    // What deinit reads, should anything below fail.
    state.own.returnValue = runtime.DOMString.initEmpty();
    state.base.own.type = runtime.DOMString.initEmpty();
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));
    state.base.own.isTrusted = false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = 0; // NONE
    state.base.own.bubbles = false;
    state.base.own.cancelable = false;
    state.base.own.composed = false;
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);
    return instance;
}

/// Deinitialize instance: the return value, then the Event it is.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    state.own.returnValue.deinit(instance.ctx.allocator);
    state.own.returnValue = runtime.DOMString.initEmpty();
    interfaces.Event.deinit(instance);
}

/// Getter for returnValue: "return the value it was last set to", initially
/// the empty string. Borrowed, as Event's own DOMString getters are.
pub fn get_returnValue(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    return runtime.DOMString.initInterned(state.own.returnValue.asSlice());
}

/// Setter for returnValue: keep a copy - the binding frees the argument when
/// the call returns.
pub fn set_returnValue(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    const state = instance.getState(State);
    const copy = try runtime.DOMString.initDupe(instance.ctx.allocator, value.asSlice());
    state.own.returnValue.deinit(instance.ctx.allocator);
    state.own.returnValue = copy;
}
