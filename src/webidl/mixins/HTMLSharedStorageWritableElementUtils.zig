//! Auto-generated mixin: HTMLSharedStorageWritableElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSharedStorageWritableElementUtilsImpl = @import("impls").HTMLSharedStorageWritableElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").HTMLSharedStorageWritableElementUtils;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "HTMLSharedStorageWritableElementUtils")) {
        if (comptime @hasDecl(impls.HTMLSharedStorageWritableElementUtils, "installHooks")) impls.HTMLSharedStorageWritableElementUtils.installHooks();
    }
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
    return try HTMLSharedStorageWritableElementUtilsImpl.get_sharedStorageWritable(instance);
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    try HTMLSharedStorageWritableElementUtilsImpl.set_sharedStorageWritable(instance, value);
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.withPendingExceptionSetAside sets aside what the member leaves
/// pending.
pub const ce_reactions = .{
    "set_sharedStorageWritable",
};
