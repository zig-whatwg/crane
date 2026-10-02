//! Auto-generated mixin: GPUDebugCommandsMixin
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUDebugCommandsMixinImpl = @import("impls").GPUDebugCommandsMixin;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").GPUDebugCommandsMixin;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GPUDebugCommandsMixin")) {
        if (comptime @hasDecl(impls.GPUDebugCommandsMixin, "installHooks")) impls.GPUDebugCommandsMixin.installHooks();
    }
}

pub fn call_insertDebugMarker(instance: *runtime.Instance, markerLabel: runtime.USVString) anyerror!void {
    return try GPUDebugCommandsMixinImpl.call_insertDebugMarker(instance, markerLabel);
}

pub fn call_pushDebugGroup(instance: *runtime.Instance, groupLabel: runtime.USVString) anyerror!void {
    return try GPUDebugCommandsMixinImpl.call_pushDebugGroup(instance, groupLabel);
}

pub fn call_popDebugGroup(instance: *runtime.Instance) anyerror!void {
    return try GPUDebugCommandsMixinImpl.call_popDebugGroup(instance);
}
