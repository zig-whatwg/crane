//! Auto-generated mixin: GPUDebugCommandsMixin
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GPUDebugCommandsMixinImpl = @import("impls").GPUDebugCommandsMixin;

// Re-export types from impl
pub const impl = @import("impls").GPUDebugCommandsMixin;

pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.JSValue) anyerror!void {
    return GPUDebugCommandsMixinImpl.call_insertDebugMarker(instance, markerLabel);
}

pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.JSValue) anyerror!void {
    return GPUDebugCommandsMixinImpl.call_pushDebugGroup(instance, groupLabel);
}

pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
    return GPUDebugCommandsMixinImpl.call_popDebugGroup(instance);
}

