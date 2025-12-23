//! Auto-generated mixin: CanvasState
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasStateImpl = @import("impls").CanvasState;

// Re-export types from impl
pub const impl = @import("impls").CanvasState;

pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    return CanvasStateImpl.call_reset(instance);
}

pub fn call_save(instance: *runtime.Instance) anyerror!void {
    return CanvasStateImpl.call_save(instance);
}

pub fn call_restore(instance: *runtime.Instance) anyerror!void {
    return CanvasStateImpl.call_restore(instance);
}

pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    return CanvasStateImpl.call_isContextLost(instance);
}

