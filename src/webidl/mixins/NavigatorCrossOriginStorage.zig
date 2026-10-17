//! Auto-generated mixin: NavigatorCrossOriginStorage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorCrossOriginStorageImpl = @import("impls").NavigatorCrossOriginStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CrossOriginStorageManager = @import("interfaces").CrossOriginStorageManager;

pub const impl = @import("impls").NavigatorCrossOriginStorage;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorCrossOriginStorage")) {
        if (comptime @hasDecl(impls.NavigatorCrossOriginStorage, "installHooks")) impls.NavigatorCrossOriginStorage.installHooks();
    }
}

/// Extended attributes: [SameObject], [SecureContext]
pub fn get_crossOriginStorage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorCrossOriginStorageImpl.get_crossOriginStorage(instance);
}
