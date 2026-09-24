//! Auto-generated mixin: AbstractWorker
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AbstractWorkerImpl = @import("impls").AbstractWorker;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventHandler = @import("typedefs").EventHandler;

pub const impl = @import("impls").AbstractWorker;

pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
    return try AbstractWorkerImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    try AbstractWorkerImpl.set_onerror(instance, value);
}
