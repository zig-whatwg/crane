//! Auto-generated mixin: GPUPipelineBase
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPUPipelineBaseImpl = @import("impls").GPUPipelineBase;

// Re-export types from impl
pub const impl = @import("impls").GPUPipelineBase;

pub fn call_getBindGroupLayout(instance: *runtime.Instance, index: runtime.JSValue) !*runtime.Instance {
    return GPUPipelineBaseImpl.call_getBindGroupLayout(instance, index);
}

