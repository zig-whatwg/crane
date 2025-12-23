//! Auto-generated mixin: NavigatorAutomationInformation
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const NavigatorAutomationInformationImpl = @import("impls").NavigatorAutomationInformation;

// Re-export types from impl
pub const impl = @import("impls").NavigatorAutomationInformation;

pub fn get_webdriver(instance: *runtime.Instance) anyerror!bool {
    return NavigatorAutomationInformationImpl.get_webdriver(instance);
}

