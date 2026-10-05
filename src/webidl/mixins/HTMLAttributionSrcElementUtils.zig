//! Auto-generated mixin: HTMLAttributionSrcElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLAttributionSrcElementUtilsImpl = @import("impls").HTMLAttributionSrcElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").HTMLAttributionSrcElementUtils;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "HTMLAttributionSrcElementUtils")) {
        if (comptime @hasDecl(impls.HTMLAttributionSrcElementUtils, "installHooks")) impls.HTMLAttributionSrcElementUtils.installHooks();
    }
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLAttributionSrcElementUtilsImpl.get_attributionSrc(instance);
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    const ce_scope = runtime.CEReactions.begin(instance);
    defer runtime.CEReactions.end(ce_scope);

    try HTMLAttributionSrcElementUtilsImpl.set_attributionSrc(instance, value);
}

/// HTML [CEReactions]: the functions that run a custom element reactions
/// bracket - the binding dispatches each in a catch scope, where
/// engine.withPendingExceptionSetAside sets aside what the member leaves
/// pending.
pub const ce_reactions = .{
    "set_attributionSrc",
};
