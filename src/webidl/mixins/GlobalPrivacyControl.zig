//! Auto-generated mixin: GlobalPrivacyControl
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GlobalPrivacyControlImpl = @import("impls").GlobalPrivacyControl;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").GlobalPrivacyControl;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GlobalPrivacyControl")) {
        if (comptime @hasDecl(impls.GlobalPrivacyControl, "installHooks")) impls.GlobalPrivacyControl.installHooks();
    }
}

pub fn get_globalPrivacyControl(instance: *runtime.Instance) anyerror!bool {
    return try GlobalPrivacyControlImpl.get_globalPrivacyControl(instance);
}
