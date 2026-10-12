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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "AbstractWorker")) {
        if (comptime @hasDecl(impls.AbstractWorker, "installHooks")) impls.AbstractWorker.installHooks();
    }
}

const event_handlers = @import("dom").event_handlers;

pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
    if (comptime @hasDecl(AbstractWorkerImpl, "get_onerror")) return try AbstractWorkerImpl.get_onerror(instance);
    return event_handlers.value(EventHandler, instance, "onerror");
}

pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
    if (comptime @hasDecl(AbstractWorkerImpl, "set_onerror")) return try AbstractWorkerImpl.set_onerror(instance, value);
    try event_handlers.setValue(EventHandler, instance, "onerror", value);
}
