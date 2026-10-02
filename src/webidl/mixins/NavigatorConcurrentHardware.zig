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

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorConcurrentHardware")) {
        if (comptime @hasDecl(impls.NavigatorConcurrentHardware, "installHooks")) impls.NavigatorConcurrentHardware.installHooks();
    }
}

pub fn get_hardwareConcurrency(instance: *runtime.Instance) anyerror!u64 {
    return try NavigatorConcurrentHardwareImpl.get_hardwareConcurrency(instance);
}
