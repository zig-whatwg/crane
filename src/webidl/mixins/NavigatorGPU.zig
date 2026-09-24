//! Auto-generated mixin: NavigatorGPU
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorGPUImpl = @import("impls").NavigatorGPU;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPU = @import("interfaces").GPU;

pub const impl = @import("impls").NavigatorGPU;

/// Extended attributes: [SameObject], [SecureContext]
pub fn get_gpu(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorGPUImpl.get_gpu(instance);
}
