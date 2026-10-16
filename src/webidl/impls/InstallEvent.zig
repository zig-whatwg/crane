//! Implementation for InstallEvent interface
//!
//! Spec: Service Workers 4.5 InstallEvent. The install event a service
//! worker's thread fires (Install step 11.3.1) is one; addRoutes() (the
//! static router) waits for Handle Fetch.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InstallEvent = interfaces.InstallEvent;

pub const State = InstallEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// No state of its own: its extended lifetime is ExtendableEvent's (the
/// generated chain hands it the `lifetime` construction argument).
pub const InternalState = struct {};

/// new InstallEvent(type, eventInitDict): DOM's inner event creation steps.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableEventInit)) !*runtime.Instance {
    const instance = try InstallEvent.init(ctx.allocator, ctx);
    errdefer InstallEvent.deinit(instance);
    const event_construction = @import("dom").event_construction;
    const event_init = if (eventInitDict.was_passed) eventInitDict.value.base else dictionaries.EventInit{};
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(event_init));
    return instance;
}

/// Operation: addRoutes
pub fn call_addRoutes(instance: *runtime.Instance, rules: runtime.JSValue) anyerror!runtime.JSValue {
    _ = instance;
    _ = rules;
    return error.NotImplemented;
}
