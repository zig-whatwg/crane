//! Auto-generated mixin: NavigatorML
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorMLImpl = @import("impls").NavigatorML;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ML = @import("interfaces").ML;

pub const impl = @import("impls").NavigatorML;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorML")) {
        if (comptime @hasDecl(impls.NavigatorML, "installHooks")) impls.NavigatorML.installHooks();
    }
}

/// Extended attributes: [SecureContext], [SameObject]
pub fn get_ml(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try NavigatorMLImpl.get_ml(instance);
}
