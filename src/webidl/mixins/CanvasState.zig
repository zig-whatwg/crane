//! Auto-generated mixin: CanvasState
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasStateImpl = @import("impls").CanvasState;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").CanvasState;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "CanvasState")) {
        if (comptime @hasDecl(impls.CanvasState, "installHooks")) impls.CanvasState.installHooks();
    }
}

pub fn call_reset(instance: *runtime.Instance) anyerror!void {
    return try CanvasStateImpl.call_reset(instance);
}

pub fn call_save(instance: *runtime.Instance) anyerror!void {
    return try CanvasStateImpl.call_save(instance);
}

pub fn call_restore(instance: *runtime.Instance) anyerror!void {
    return try CanvasStateImpl.call_restore(instance);
}

pub fn call_isContextLost(instance: *runtime.Instance) anyerror!bool {
    return try CanvasStateImpl.call_isContextLost(instance);
}
