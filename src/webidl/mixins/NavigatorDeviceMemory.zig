//! Auto-generated mixin: NavigatorDeviceMemory
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorDeviceMemoryImpl = @import("impls").NavigatorDeviceMemory;

// Re-export types from impl
pub const impl = @import("impls").NavigatorDeviceMemory;

pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
    return NavigatorDeviceMemoryImpl.get_deviceMemory(instance);
}

