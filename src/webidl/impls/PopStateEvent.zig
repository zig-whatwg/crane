//! Implementation for PopStateEvent interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
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

/// The event's own hold on `state` when it is a script value: `state` is a
/// view of it, released in deinit. The dictionary member's handle the
/// binding converted is the binding's, released once the constructor returns
/// (WebIDL: an `any` value is borrowed for the call). Interim: `state` moves
/// onto the engine's traced-value pair when it lands (queued).
pub const InternalState = struct {
    state_hold: ?engine.Owned = null,
};

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
    // A cloned string is freed; a script value's view is the hold's.
    state.own.state.deinit(instance.ctx.allocator);
    if (state.own._internal) |internal| {
        if (internal.state_hold) |held| held.release();
        instance.ctx.allocator.destroy(internal);
        state.own._internal = null;
        state.own.state = runtime.JSValue.jsNull;
    }
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

    // The event's own: a string cloned (the binding frees the dictionary's
    // strings when the constructor returns), a script value held.
    state.own.state = if (init_dict.state) |value| try keepState(ctx, instance, value) else runtime.JSValue.jsNull;
    state.own.hasUAVisualTransition = init_dict.hasUAVisualTransition orelse false;

    // The inherited Event internal state and its initialized flag: without
    // them dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, runtime.ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// The event's own copy of `value`: a script value under a hold of the
/// event's (`InternalState.state_hold`), anything else cloned.
fn keepState(ctx: runtime.Context, instance: *runtime.Instance, value: runtime.JSValue) !runtime.JSValue {
    switch (value) {
        .handle, .instance => {
            const state = instance.getState(State);
            const internal = try ctx.allocator.create(InternalState);
            internal.* = .{};
            state.own._internal = internal;
            const held = try engine.retainValue(ctx, value);
            internal.state_hold = held;
            return held.value;
        },
        else => return value.clone(ctx.allocator),
    }
}

/// Getter for state. The event keeps the value it was initialized to; a
/// handle goes to the binding as a hold of its own, and a string as a
/// reference - the binding frees a string result handed over owned, and this
/// one is the event's (the constructor's clone).
pub fn get_state(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const kept = instance.getState(State).own.state;
    return switch (kept) {
        .handle => (try engine.retainValue(instance.ctx, kept)).take(),
        .string => |text| runtime.JSValue.fromStringRef(text.data),
        else => kept,
    };
}

/// Getter for hasUAVisualTransition
pub fn get_hasUAVisualTransition(instance: *runtime.Instance) anyerror!bool {
    return instance.getState(State).own.hasUAVisualTransition;
}
