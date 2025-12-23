//! Auto-generated mixin: GPUBindingCommandsMixin
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPUBindingCommandsMixinImpl = @import("impls").GPUBindingCommandsMixin;

// Re-export types from impl
pub const impl = @import("impls").GPUBindingCommandsMixin;

/// Arguments for setBindGroup (WebIDL overloading)
pub const SetBindGroupArgs = union(enum) {
    /// setBindGroup(index, bindGroup, dynamicOffsets)
    GPUIndex32_GPUBindGroup_sequence: struct {
        index: typedefs.GPUIndex32,
        bindGroup: ?*runtime.Instance,
        dynamicOffsets: webidl.Opt(runtime.JSValue),
    },
    /// setBindGroup(index, bindGroup, dynamicOffsetsData, dynamicOffsetsDataStart, dynamicOffsetsDataLength)
    GPUIndex32_GPUBindGroup_Uint32Array_GPUSize64_GPUSize32: struct {
        index: typedefs.GPUIndex32,
        bindGroup: ?*runtime.Instance,
        dynamicOffsetsData: runtime.JSValue,
        dynamicOffsetsDataStart: typedefs.GPUSize64,
        dynamicOffsetsDataLength: typedefs.GPUSize32,
    },
};

pub fn call_setBindGroup(instance: *runtime.Instance, args: SetBindGroupArgs) anyerror!void {
    return GPUBindingCommandsMixinImpl.call_setBindGroup(instance, args);
}

