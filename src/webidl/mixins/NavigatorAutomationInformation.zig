//! Auto-generated mixin: NavigatorAutomationInformation
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigatorAutomationInformationImpl = @import("impls").NavigatorAutomationInformation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").NavigatorAutomationInformation;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "NavigatorAutomationInformation")) {
        if (comptime @hasDecl(impls.NavigatorAutomationInformation, "installHooks")) impls.NavigatorAutomationInformation.installHooks();
    }
}

pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
    return try NavigatorAutomationInformationImpl.get_webdriver(instance);
}
