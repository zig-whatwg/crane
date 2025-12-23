//! Auto-generated mixin: AbstractWorker
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AbstractWorkerImpl = @import("impls").AbstractWorker;

// Re-export types from impl
pub const impl = @import("impls").AbstractWorker;

pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return AbstractWorkerImpl.get_onerror(instance);
}

pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) !void {
    return AbstractWorkerImpl.set_onerror(instance, value);
}

