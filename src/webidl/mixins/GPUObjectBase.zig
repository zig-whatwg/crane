//! Auto-generated mixin: GPUObjectBase
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPUObjectBaseImpl = @import("impls").GPUObjectBase;

// Re-export types from impl
pub const impl = @import("impls").GPUObjectBase;

pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
    return GPUObjectBaseImpl.get_label(instance);
}

pub fn set_label(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return GPUObjectBaseImpl.set_label(instance, value);
}

