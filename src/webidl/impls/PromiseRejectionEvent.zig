//! Implementation for PromiseRejectionEvent interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#promiserejectionevent
//! HTML Standard §8.1.4.7 Unhandled promise rejections
//!
//! Fired at the global as "unhandledrejection" and "rejectionhandled" by the
//! promise rejection tracker (src/html/rejected_promises.zig), and constructible
//! from script.
//!
//! This was the codegen stub until now: the constructor ignored its arguments,
//! both getters threw NotImplemented, and `init` never set up the Event state -
//! so even `new PromiseRejectionEvent(...)` produced an event dispatchEvent
//! rejected as uninitialized.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const clock = @import("clock");
const v8 = @import("v8");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const PromiseRejectionEvent = interfaces.PromiseRejectionEvent;

pub const State = PromiseRejectionEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state: the two attributes, as Global<Value>* handles this event
/// OWNS - the values arrive in Globals their owners dispose (a dictionary
/// member's is the conversion's; the tracker's is the tracker's), so storing
/// them as they came would leave the getters reading freed handles.
pub const InternalState = struct {
    /// The promise this notification is about (required by the init dict).
    promise: ?*v8.ffi.Value = null,
    /// The rejection reason, or null for undefined.
    reason: ?*v8.ffi.Value = null,
};

const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.promise) |value| v8.ffi.v8_Global_Dispose(value);
        if (internal.reason) |value| v8.ffi.v8_Global_Dispose(value);
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, internal);
        state.own._internal = null;
    }
    // Event's own resources (type string, internal state).
    interfaces.Event.deinit(instance);
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#promiserejectionevent
/// The event constructing steps (DOM "inner event creation steps"): the Event
/// attributes from EventInit, then promise and reason from the dictionary.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.PromiseRejectionEventInit) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &PromiseRejectionEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = .{};
    state.own._internal = internal;

    // Event base attributes (state.base.own), as ErrorEvent sets them.
    const event_init = eventInitDict.base;
    state.base.own.type = try @"type".clone(ctx.allocator);
    state.base.own.bubbles = event_init.bubbles orelse false;
    state.base.own.cancelable = event_init.cancelable orelse false;
    state.base.own.composed = event_init.composed orelse false;
    state.base.own.target = null;
    state.base.own.srcElement = null;
    state.base.own.currentTarget = null;
    state.base.own.eventPhase = interfaces.Event.get_NONE();
    state.base.own.cancelBubble = false;
    state.base.own.returnValue = true;
    state.base.own.defaultPrevented = false;
    state.base.own.isTrusted = false;
    state.base.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));

    internal.promise = retainValue(eventInitDict.promise);
    if (eventInitDict.reason) |reason| internal.reason = retainValue(reason);

    // Without the initialized flag dispatchEvent throws InvalidStateError.
    try webidl.utils.initEventBase(&state.base.own, ArenaAllocator.get(), ctx.allocator);

    return instance;
}

/// A Global<Value>* of `value` this event owns, or null for undefined.
/// A runtime.JSValue handle is always a Global<Value>* whatever its
/// `handle_scope` tag says (AGENTS.md "One handle kind per layer"), so it is
/// cloned; a primitive is materialised as a V8 value.
fn retainValue(value: runtime.JSValue) ?*v8.ffi.Value {
    const isolate = v8.ffi.v8_Isolate_GetCurrent() orelse return null;
    return switch (value) {
        .undefined => null,
        .null => v8.ffi.v8_Null(isolate),
        .boolean => |b| v8.ffi.v8_Boolean_New(isolate, b),
        .number => |n| @ptrCast(v8.ffi.v8_Number_New(isolate, n)),
        .string => |str| @ptrCast(v8.ffi.v8_String_NewFromUtf8(isolate, str.data.ptr, @intCast(str.data.len))),
        .handle => |h| v8.ffi.v8_Global_Clone(@ptrCast(@alignCast(h.ptr))),
        .instance => null,
    };
}

/// Getter for promise
/// Spec: "The promise attribute must return the value it was initialized to."
pub fn get_promise(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return runtime.JSValue.jsUndefined;
    if (internal.promise) |value| return runtime.JSValue.fromHandleNonOwning(value);
    return runtime.JSValue.jsUndefined;
}

/// Getter for reason
/// Spec: "The reason attribute must return the value it was initialized to."
pub fn get_reason(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return runtime.JSValue.jsUndefined;
    if (internal.reason) |value| return runtime.JSValue.fromHandleNonOwning(value);
    return runtime.JSValue.jsUndefined;
}
