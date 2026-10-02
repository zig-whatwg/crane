//! Auto-generated mixin: NavigatorCookies
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorCookiesImpl = @import("impls").NavigatorCookies;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorCookies;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorCookies")) {
        if (comptime @hasDecl(impls.NavigatorCookies, "installHooks")) impls.NavigatorCookies.installHooks();
    }
}

pub fn get_cookieEnabled(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorCookiesImpl.get_cookieEnabled(instance);
}
