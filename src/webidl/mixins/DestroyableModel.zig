//! Auto-generated mixin: DestroyableModel
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DestroyableModelImpl = @import("impls").DestroyableModel;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").DestroyableModel;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "DestroyableModel")) {
        if (comptime @hasDecl(impls.DestroyableModel, "installHooks")) impls.DestroyableModel.installHooks();
    }
}

pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
    return try DestroyableModelImpl.call_destroy(instance);
}
