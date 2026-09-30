//! Implementation for FormDataEvent interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-formdataevent-interface
//!
//! ```idl
//! [Exposed=Window]
//! interface FormDataEvent : Event {
//!   constructor(DOMString type, FormDataEventInit eventInitDict);
//!   readonly attribute FormData formData;
//! };
//! dictionary FormDataEventInit : EventInit {
//!   required FormData formData;
//! };
//! ```
//!
//! Fired by "constructing the entry list" (HTMLFormElement.zig) at the form,
//! and constructed by script.

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
const FormDataEvent = interfaces.FormDataEvent;

pub const State = FormDataEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// "The formData attribute must return the value it was initialized to."
/// The event holds the FormData's wrapper strongly, as Blink traces
/// `form_data_` from the event: a listener reads `e.formData` after the
/// FormData was made for it and nothing else refers to it. A FormData
/// points at nothing, so the hold makes no cycle.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    form_data: ?*runtime.Instance = null,
    pin: same_object.Pin = .{},
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

/// Deinitialize instance: release the FormData, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.pin.release();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    EventImpl.deinit(instance);
}

/// Constructor: DOM "inner event creation steps", then formData.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.FormDataEventInit) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &FormDataEvent.vtable, ctx);
    errdefer deinit(instance);
    try EventImpl.innerEventCreationSteps(instance, @"type", eventInitDict.base);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.form_data = eventInitDict.formData;
    internal.pin.hold(eventInitDict.formData);
    return instance;
}

/// Getter for formData
pub fn get_formData(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.form_data orelse error.InvalidStateError;
}
