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

pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!EventHandler {
    return try ServiceEventHandlersImpl.get_onserviceadded(instance);
}

pub fn set_onserviceadded(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try ServiceEventHandlersImpl.set_onserviceadded(instance, value);
}

pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!EventHandler {
    return try ServiceEventHandlersImpl.get_onservicechanged(instance);
}

pub fn set_onservicechanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try ServiceEventHandlersImpl.set_onservicechanged(instance, value);
}

pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!EventHandler {
    return try ServiceEventHandlersImpl.get_onserviceremoved(instance);
}

pub fn set_onserviceremoved(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try ServiceEventHandlersImpl.set_onserviceremoved(instance, value);
}
