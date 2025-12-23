//! Auto-generated mixin: AnimationFrameProvider
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const AnimationFrameProviderImpl = @import("impls").AnimationFrameProvider;

// Re-export types from impl
pub const impl = @import("impls").AnimationFrameProvider;

pub fn call_cancelAnimationFrame(instance: *runtime.Instance, handle: runtime.JSValue) anyerror!void {
    return AnimationFrameProviderImpl.call_cancelAnimationFrame(instance, handle);
}

pub fn call_requestAnimationFrame(instance: *runtime.Instance, callback: callbacks.FrameRequestCallback) anyerror!u32 {
    return AnimationFrameProviderImpl.call_requestAnimationFrame(instance, callback);
}

