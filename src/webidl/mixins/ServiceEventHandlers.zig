//! Auto-generated mixin: ServiceEventHandlers
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceEventHandlersImpl = @import("impls").ServiceEventHandlers;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").ServiceEventHandlers;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ServiceEventHandlers")) {
        if (comptime @hasDecl(impls.ServiceEventHandlers, "installHooks")) impls.ServiceEventHandlers.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onserviceadded")) return try ServiceEventHandlersImpl.get_onserviceadded(instance);
    return event_handlers.value(EventHandler, instance, "onserviceadded");
}

pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onserviceadded")) return try ServiceEventHandlersImpl.set_onserviceadded(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onserviceadded", value);
}

pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onservicechanged")) return try ServiceEventHandlersImpl.get_onservicechanged(instance);
    return event_handlers.value(EventHandler, instance, "onservicechanged");
}

pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onservicechanged")) return try ServiceEventHandlersImpl.set_onservicechanged(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onservicechanged", value);
}

pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "get_onserviceremoved")) return try ServiceEventHandlersImpl.get_onserviceremoved(instance);
    return event_handlers.value(EventHandler, instance, "onserviceremoved");
}

pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(ServiceEventHandlersImpl, "set_onserviceremoved")) return try ServiceEventHandlersImpl.set_onserviceremoved(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onserviceremoved", value);
}
