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

pub fn get_deviceMemory(instance: *runtime.Instance) anyerror!f64 {
    return try NavigatorDeviceMemoryImpl.get_deviceMemory(instance);
}
