//! Implementation for PopStateEvent interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const PopStateEvent = interfaces.PopStateEvent;

pub const State = PopStateEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    state.own.state.deinit(instance.ctx.allocator);
    // The Event part: the cloned type and the inherited internal state.
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#popstateevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.PopStateEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &PopStateEvent.vtable, ctx);
    errdefer deinit(instance);
    const state = instance.getState(State);
    const init_dict = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.PopStateEventInit{ .base = .{} };
    // What deinit reads, should anything below fail.
    state.base.own.type = runtime.DOMString.initEmpty();
    state.own.state = runtime.JSValue.jsNull;
    state.own.hasUAVisualTransition = false;

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

    // Cloned: the binding frees the dictionary's strings when the
    // constructor returns (see MessageEvent's `data`).
    state.own.state = if (init_dict.state) |value| try value.clone(ctx.allocator) else runtime.JSValue.jsNull;
    state.own.hasUAVisualTransition = init_dict.hasUAVisualTransition orelse false;

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// Getter for state
pub fn get_state(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return instance.getState(State).own.state;
}

/// Getter for hasUAVisualTransition
pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.hasUAVisualTransition;
}
