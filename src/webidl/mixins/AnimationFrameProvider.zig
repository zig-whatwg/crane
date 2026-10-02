//! Auto-generated mixin: AnimationFrameProvider
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AnimationFrameProviderImpl = @import("impls").AnimationFrameProvider;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FrameRequestCallback = @import("callbacks").FrameRequestCallback;

pub const impl = @import("impls").AnimationFrameProvider;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "AnimationFrameProvider")) {
        if (comptime @hasDecl(impls.AnimationFrameProvider, "installHooks")) impls.AnimationFrameProvider.installHooks();
    }
}

pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: u32) anyerror!void {
    return try AnimationFrameProviderImpl.call_cancelAnimationFrame(instance, handle);
}

pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: FrameRequestCallback) anyerror!u32 {
    return try AnimationFrameProviderImpl.call_requestAnimationFrame(instance, callback);
}
