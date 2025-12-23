//! Auto-generated mixin: NavigatorGPU
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorGPUImpl = @import("impls").NavigatorGPU;

// Re-export types from impl
pub const impl = @import("impls").NavigatorGPU;

pub fn get_gpu(instance: *runtime.Instance) !*runtime.Instance {
    return NavigatorGPUImpl.get_gpu(instance);
}

