//! Auto-generated mixin: NavigatorStorage
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorStorageImpl = @import("impls").NavigatorStorage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StorageManager = @import("interfaces").StorageManager;

pub const impl = @import("impls").NavigatorStorage;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorStorage")) {
        if (comptime @hasDecl(impls.NavigatorStorage, "installHooks")) impls.NavigatorStorage.installHooks();
    }
}

/// Extended attributes: [SameObject]
pub fn get_storage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorStorageImpl.get_storage(instance);
}
