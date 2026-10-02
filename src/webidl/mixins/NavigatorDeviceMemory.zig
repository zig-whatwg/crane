//! Auto-generated mixin: NavigatorDeviceMemory
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorDeviceMemoryImpl = @import("impls").NavigatorDeviceMemory;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorDeviceMemory;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorDeviceMemory")) {
        if (comptime @hasDecl(impls.NavigatorDeviceMemory, "installHooks")) impls.NavigatorDeviceMemory.installHooks();
    }
}

pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
    return try NavigatorDeviceMemoryImpl.get_deviceMemory(instance);
}
