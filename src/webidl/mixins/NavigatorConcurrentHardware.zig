//! Auto-generated mixin: NavigatorConcurrentHardware
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorConcurrentHardwareImpl = @import("impls").NavigatorConcurrentHardware;

// Re-export types from impl
pub const impl = @import("impls").NavigatorConcurrentHardware;

pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    return NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(instance);
}

