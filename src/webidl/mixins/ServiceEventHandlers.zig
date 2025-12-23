//! Auto-generated mixin: ServiceEventHandlers
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ServiceEventHandlersImpl = @import("impls").ServiceEventHandlers;

// Re-export types from impl
pub const impl = @import("impls").ServiceEventHandlers;

pub fn get_onserviceadded(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return ServiceEventHandlersImpl.get_onserviceadded(instance);
}

pub fn set_onserviceadded(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return ServiceEventHandlersImpl.set_onserviceadded(instance, value);
}

pub fn get_onservicechanged(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return ServiceEventHandlersImpl.get_onservicechanged(instance);
}

pub fn set_onservicechanged(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return ServiceEventHandlersImpl.set_onservicechanged(instance, value);
}

pub fn get_onserviceremoved(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return ServiceEventHandlersImpl.get_onserviceremoved(instance);
}

pub fn set_onserviceremoved(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return ServiceEventHandlersImpl.set_onserviceremoved(instance, value);
}

