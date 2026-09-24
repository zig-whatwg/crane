//! Auto-generated mixin: NavigatorConcurrentHardware
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorConcurrentHardwareImpl = @import("impls").NavigatorConcurrentHardware;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorConcurrentHardware;

pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    return try NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(instance);
}
